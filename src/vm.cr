require "./risc16"

module RiSC16

  class VM

    class BusError < ::Exception
      def initialize(address)
        super("Bad address: #{address}")
      end
    end

    # Memory Mapped IO
    # Duplex RW register
    class MMIO
      @in : IO
      @out : IO
      
      def initialize(@in, @out) end
      
      def read : Word
        @in.read_bytes Word, IO::ByteFormat::LittleEndian
      end
      
      def write(word : Word)
        word.to_io @out, IO::ByteFormat::LittleEndian
      end
    end
        
    @ram_range : Range(Word, Word)
    property ram : Array(UInt16)
    @io_range : Range(Word, Word)
    property io : Array(MMIO)
    property registers = Array(UInt16).new REGISTER_COUNT, 0_i16
    property pc = 0_u16
    property halted = false
    @instruction : Instruction

    # Build a VM from a specfile. Allow override of IO for easier debugging.
    def self.from_spec(spec, io_override = {} of String => MMIO)
      io = Array(MMIO).new(spec.io_size) do |index|
        io_spec = spec.io.find(&.index.==(index)) || raise "Missing IO for index #{index} in specs"
        io_override[io_spec.name]? || begin
          input = io_spec.stdio ? STDIN : File.open io_spec.input, "r"
          output = io_spec.stdio ? STDOUT : File.open io_spec.output, "w"
          MMIO.new in: input, out: output
        end
      end
      self.new spec.ram_size, spec.ram_start, spec.io_start, io
    end
    
    def initialize(ram_size, ram_start, io_start, @io)
      @ram_range = ram_start..(ram_start + (ram_size - 1))
      @io_range = io_start..(io_start + (@io.size - 1))
      raise "Address space overlap: ram: #{@ram_range}, io: #{@io_range}" if @ram_range.any?(&.in? @io_range) || @io_range.any?(&.in? @ram_range)
      @ram = Array(UInt16).new ram_size, 0_u16
      @instruction = Instruction.decode 0u16
    end

    # Load a program at the given address. Raise if it reach an address that does not map to ram.
    def load(program, at = 0)
      program.each_byte do |byte|
        raise BusError.new at // 2 unless @ram_range.includes? at // 2
        ram[at // 2 - @ram_range.begin] |= byte.to_u16 << 8 * (at % 2)
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
end
