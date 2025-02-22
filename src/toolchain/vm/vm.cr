require "../risc16"
require "io/evented"

class RiSC16::VM
  class BusError < ::Exception
    def initialize(address)
      super("Bad address: #{address}")
    end
  end

  abstract class Addressable
    abstract def read(address : UInt16, timeout = nil) : UInt16
    abstract def write(address : UInt16, value : UInt16, timeout = nil)

    class Ram < Addressable
      @data : Slice(UInt16)
      property start : UInt16
      property size : UInt16

      def initialize(segment : RiSC16::Spec::Segment::Ram)
        @start = segment.start
        @size = segment.size
        @data = Slice(UInt16).new segment.size
      end

      def read(address : UInt16, timeout = nil) : UInt16
        @data[address - @start]
      end

      def write(address : UInt16, value : UInt16, timeout = nil)
        @data[address - @start] = value
      end
    end

    class Rom < Ram
      property start : UInt16
      property size : UInt16

      def initialize(segment : RiSC16::Spec::Segment::Rom, fs)
        @start = segment.start
        @size = segment.size
        @data = Slice(UInt16).new segment.size
        input_name = segment.source
        fs.read input_name do |io|
          0.upto segment.size do |index|
            @data[index] = Word.from_io io, ::IO::ByteFormat::BigEndian
          end
        end
      end
    end

    class IO < Addressable
      property start : UInt16
      property size : UInt16
      @read : ::IO?
      @write : ::IO?
      @do_close = true

      def initialize(segment : RiSC16::Spec::Segment::IO, fs, io_mapping)
        @start = segment.start
        @size = 1u16
        overrides = io_mapping[segment.name]?
        source  = 
        if overrides
          @do_close = false
          @read, @write = overrides
        else
          segment.source.try do |source|
            @read = fs.open source, "r"
            @write = nil
          end
          segment.sink.try do |sink|
            @write = fs.open sink, "w"
            @read = nil
          end
        end
      end

      def close
        return unless @do_close
        @read.try &.close
        @write.try &.close
      end

      def finalize
        close
      end

      EOS = 0xff00u16

      def read(address : Word, timeout = nil) : Word
        raise BusError.new address unless address == @start
        @read.as?(::IO::FileDescriptor).try(&.read_timeout = timeout) if timeout
        value = @read.try &.read_byte.try &.to_u16 || EOS
        return value
      end

      def write(address : Word, value : Word, timeout = nil)
        raise BusError.new address unless address == @start
        @read.as?(::IO::FileDescriptor).try(&.write_timeout = timeout) if timeout
        (value & 0xff).to_u8.to_io @write.not_nil!, ::IO::ByteFormat::BigEndian if @write
      end
    end

    class Default < Addressable
      @read : Bool = true
      @write : Bool = false
      getter start = 0x0u16
      getter size = 0xffffu16

      def initialize
      end

      def initialize(segment : RiSC16::Spec::Segment::Default)
        @read = segment.read
        @write = segment.write
      end

      def read(address : UInt16, timeout = nil) : UInt16
        raise BusError.new address unless @read
        0u16
      end

      def write(address : UInt16, value : UInt16, timeout = nil)
        raise BusError.new address unless @write
      end
    end
  end

  @address_space : Array(Addressable)
  @default : Addressable
  property registers = Array(UInt16).new REGISTER_COUNT, 0_i16
  property pc = 0_u16
  property halted = false
  @instruction : Instruction

  def self.from_spec(spec, fs, io_mapping)
    segments = [] of Addressable
    default = Addressable::Default.new
    spec.segments.sort_by(&.start).reduce(0) { |address, segment|
      segments << case segment
      when RiSC16::Spec::Segment::Rom
        Addressable::Rom.new segment, fs
      when RiSC16::Spec::Segment::Ram
        Addressable::Ram.new segment
      when RiSC16::Spec::Segment::IO
        Addressable::IO.new segment, fs, io_mapping
      when RiSC16::Spec::Segment::Default
        Addressable::Default.new segment
      else raise "Unknown segment kind"
      end
      segment.start.to_i + segment.size
    }
    self.new segments, default
  end

  def initialize(@address_space, @default)
    @instruction = Instruction.decode 0u16
  end

  def close
    @address_space.each do |segment|
      case segment
      when Addressable::IO
        segment.close
      end
    end
  end

  def segment(address)
    @address_space.find do |segment|
      address >= segment.start && address < segment.start.to_i + segment.size
    end || raise BusError.new address
  end

  def read(address : Word, timeout = nil) : Word
    segment(address).read(address, timeout)
  end

  def read_noio(address : Word) : Word?
    seg = segment(address)
    case seg
    when Addressable::Rom, Addressable::Ram then seg.read(address)
    end
  end

  def write(address : Word, value : Word, timeout = nil)
    segment(address).write(address, value, timeout)
  end

  def load(program : Bytes, at = 0)
    program.each do |byte|
      raise "Program overflow address space at #{at}" if at > UInt16::MAX
      write((at.to_u16 // 2), (read(at.to_u16 // 2) | byte.to_i16 << 8 * ((at + 1) % 2)))
      at += 1
    end
  end

  def write_reg_a(v)
    registers[@instruction.reg_a] = v
  end

  def reg_a
    registers[@instruction.reg_a]
  end

  def reg_b
    registers[@instruction.reg_b]
  end

  def reg_c
    registers[@instruction.reg_c]
  end

  def add(a : UInt16, b : UInt16) : UInt16
    (a.to_u32 + b.to_u32).bits(0...16).to_u16
  end

  def step(timeout = nil)
    @instruction = Instruction.decode read @pc
    case @instruction.opcode
    when ISA::Add  then write_reg_a add reg_b, reg_c
    when ISA::Addi then write_reg_a add reg_b, @instruction.immediate
    when ISA::Nand then write_reg_a ~(reg_b & reg_c)
    when ISA::Lui  then write_reg_a @instruction.immediate << 6
    when ISA::Sw
      address = add reg_b, @instruction.immediate
      write(address, reg_a, timeout)
    when ISA::Lw
      address = add reg_b, @instruction.immediate
      write_reg_a read(address, timeout)
    when ISA::Beq then @pc = add @pc, @instruction.immediate if reg_a == reg_b
    when ISA::Jalr
      return @halted = true if @instruction.immediate != 0
      ret = @pc + 1
      @pc = reg_b
      write_reg_a ret
    end
    @pc += 1 unless @instruction.opcode.jalr?
    registers[0] = 0
    @halted
  end

  def run(step_limit = nil, throttling : Time::Span? = nil, timeout : Time::Span? = nil) : Int32
    step_counter = 0
    batching = 100
    batch_count = 0
    batch_start = Time.monotonic
    run_start = batch_start
    batch_timeout = timeout.try { timeout - (batch_start - run_start) }

    while !@halted
      
      begin
        step batch_timeout
      rescue ex: ::IO::TimeoutError
        raise "VM run timeout on IO after #{(Time.monotonic - run_start).total_microseconds.to_i}us"
      end

      step_counter += 1
      if step_limit && step_counter > step_limit
        raise "VM executed instruction count exceeded maximum allowed: #{step_limit}"
      end

      batch_count += 1
      batch_end = Time.monotonic
      
      if timeout && batch_end - run_start > timeout
        raise "VM run timeout after #{(batch_end - run_start).total_microseconds.to_i}us"
      end

      if batch_count == batching
        if throttling && batch_end - batch_start < throttling * batching
          sleep throttling * batching - (batch_end - batch_start)
        end

        batch_count = 0
        batch_start = batch_end
        batch_timeout = timeout.try { timeout - (batch_start - run_start) }
      end
    end
    return step_counter
  end
end
