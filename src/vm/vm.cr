require "../risc16"

class RiSC16::VM

  class BusError < ::Exception
    def initialize(address)
      super("Bad address: #{address}")
    end
  end
  
  abstract class Addressable
    abstract def read(address : UInt16) : UInt16
    abstract def write(address : UInt16, value : UInt16)

    class Ram < Addressable
      @data : Slice(UInt16)
      @start : UInt16

      def initialize(segment : RiSC16::Spec::Segment::Ram)
        @start = segment.start
        @data = Slice(UInt16).new segment.size
      end
      
      def read(address : UInt16) : UInt16
        @data[address - @start]
      end
      
      def write(address : UInt16, value : UInt16) : UInt16
        @data[address - @start] = value
      end
    end

    class Rom < Ram
      @start : UInt16

      def initialize(segment : RiSC16::Spec::Segment::Rom)
        @start = segment.start
        @data = Slice(UInt16).new segment.size
        File.open segment.source &.read @rom
      end  
    end

    class IO < Addressable
      @start : UInt16
      @read : IO
      @write : IO
      @opened : IO? = nil
      
      def initialize(segment : RiSC16::Spec::Segment::IO)
        @start = segment.start
        if segment.tty
          @read = STDIN
          @write = STDOUT
        else
          @read = @write = @opened = File.open segment.source.not_nil! 
        end
      end

      def finalize
        @opened.close
      end

      EOS = 0xff00u16
      
      def read : Word
        @read.try &.read_byte.try &.to_u16 || EOS
      end
      
      def write(word : Word)
        (word & 0xff).to_u8.to_io @write.not_nil!, IO::ByteFormat::BigEndian if @write
      end
    end

    class Default < Addressable
      @read : Boolean = true
      @write : Boolean = false
      
      def initialize(segment : RiSC16::Spec::Segment::Default)
        @read = segment.read
        @write = segment.write
      end

      def initialize
      end

      def read(address : UInt16) : UInt16
	raise BusError.new address unless @read
        0u16
      end

      def write(address : UInt16, value : UInt16) : UInt16
      	raise BusError.new address unless @write
      end
    end
    
  end
    
  @address_space : Array(Addressable)
  property registers = Array(UInt16).new REGISTER_COUNT, 0_i16
  property pc = 0_u16
  property halted = false
  @instruction : Instruction

  # Build a VM from a specfile. Allow override of IO for easier debugging.
  def self.from_spec(spec, io_override = {} of String => MMIO)
    self.new spec.segments.order_by(&.start).reduce(0u16) do |address, segment|
      segments = [] of Addressable
      raise "Segment overlap" if segment.start < address
      segments << {address...(segment.start), Default.new} if segment.start > address
      segments << case segment
      when RiSC16::Spec::Segment::Rom then Rom.new segment
      when RiSC16::Spec::Segment::Ram then Ram.new segment
      when RiSC16::Spec::Segment::IO then IO.new segment
      when RiSC16::Spec::Segment::Default then Default.new segment
      else raise "Unknown segment kind"
      end
      segments
    end.flatten.to_h
  end
    
  def initialize(@address_space)
    @instruction = Instruction.decode 0u16
  end

  def segment(address)
    @address_space.find do |segment|
      segment.start >= address && segment.start + segment.size < address
    end
  end

  def read(address : Word): Word
    segment(address).read(address)
  end

  def write(address : Word, value : Word)
    segment(address).word(address, value)
  end
  
  # read to address space
  # write to address space
  
  # Load a program at the given address. Raise if it reach an address that does not map to ram.
  def load(program, at = 0)
    program.each_byte do |byte|
      raise BusError.new at // 2 unless @ram_range.includes? at // 2
      ram[at // 2 - @ram_range.begin] |= byte.to_u16 << 8 * ((at + 1) % 2)
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
  
  def add(a : UInt16, b : UInt16): UInt16
    (a.to_u32 + b.to_u32).bits(0...16).to_u16
  end      
  
  def step
    @instruction = Instruction.decode ram[@pc]
    case @instruction.opcode
    when ISA::Add then write_reg_a add reg_b, reg_c
    when ISA::Addi then write_reg_a add reg_b, @instruction.immediate
    when ISA::Nand then write_reg_a ~(reg_b & reg_c)
    when ISA::Lui then write_reg_a @instruction.immediate << 6
    when ISA::Sw
      address = add reg_b, @instruction.immediate
      if address.in? @ram_range
        
        ram[address - @ram_range.begin] = reg_a
      elsif address.in? @io_range
        @io[address - @io_range.begin].write reg_a
      else
        raise BusError.new "address: 0x#{address.to_s(base: 16)} (#{address}) io: #{@io_range} ram: #{@ram_range}"
      end
    when ISA::Lw
      address = add reg_b, @instruction.immediate
      if address.in? @ram_range
        write_reg_a ram[address - @ram_range.begin]
      elsif address.in? @io_range
        write_reg_a @io[address - @io_range.begin].read
      else
        raise BusError.new address
      end        
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

  def run
    while !@halted
      step
    end
  end
end
