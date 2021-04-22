module RiSC16
  VERSION = {{ `shards version`.chomp.stringify }}

  alias Word = UInt16

  struct Word
    def to_w
      to_s(base: 16).rjust(4, '0')
    end
  end

  class IORegister
    property io : ::IO
    property address : Word
    def initialize(@io, @address) end
  end

  # Register 0 is always zero. Write are discarded.
  REGISTER_COUNT = 8
  MAX_MEMORY_SIZE = 1 + UInt16::MAX # In word. Ram address words.
  DEFAULT_RAM_START = 0u16
  MAX_IMMEDIATE = 0b1111111u16
  
  # Instruction set as per [RiSC16 ISA](# https://user.eng.umd.edu/~blj/RiSC/RiSC-isa.pdf).
  enum ISA
    Add = 0b000 # rrr, add two register and store in third
    Addi = 0b001 # rri, add register and 7 bit immediate and store in third
    Nand = 0b010 # rrr, nand two register and store in third
    Lui = 0b011 # ri, load 10 bit immediate and store in 10 upper bits of register 
    Sw = 0b100 # rri, store value from register in ram at position of register + immediate
    Lw = 0b101 # rri, read value from ram at position of register + immediate in register
    Beq = 0b110 # rri, jump to relative immediate if rwo registers are equal 
    Jalr = 0b111 # rri, store pc in first reg, then jump to second. Immediate must be 0, or processor halts.
  end

  # A RiSC16 instruction
  class Instruction
    getter opcode : ISA
    getter reg_a : UInt16
    getter reg_b : UInt16
    getter reg_c : UInt16
    getter immediate : UInt16
    
    def initialize(@opcode, @reg_a = 0_u16, @reg_b = 0_u16, @reg_c = 0_u16, @immediate = 0_u16)
    end

    # return the instruction encoded as a 16 bit integer.
    def encode
      instruction = @op.value.to_u16 << 13
      case @op
      when ISA::Add, ISA::Nand
        instruction |= ((@reg_a & 0b111) << 10) | ((@reg_b & 0b111) << 7) | @reg_c & 0b111
      when ISA::Addi, ISA::Sw, ISA::Lw, ISA::Beq, ISA::Jalr
        raise "Immediate overflow #{@immediate.to_s base: 16} for #{@op}" if @immediate > ~(~0 << 7)
        instruction |= ((@reg_a & 0b111) << 10) | ((@reg_b & 0b111) << 7) | (@immediate & 0b1111111)
      when ISA::Lui
        raise "Immediate overflow #{@immediate.to_s base: 16} for #{@op}" if @immediate > ~(~0 << 10)
        instruction |= ((@reg_a & 0b111) << 10) | (@immediate & 0b_11_1111_1111)
      end
      instruction
    end

    def self.decode(instruction : Word): self
      opcode = ISA.from_value instruction >> 13
      reg_a = (instruction >> 10) & 0b111
      reg_b = (instruction >> 7) & 0b111
      reg_c = instruction & 0b111
      immediate = case opcode
      when ISA::Addi, ISA::Sw, ISA::Lw, ISA::Beq, ISA::Jalr
        if (instruction & 0b1_000_000 != 0)
          ((2_u32 ** 16) - ((2 ** 7) - (instruction & 0b1111111))).bits(0...16).to_u16
        else
          instruction & 0b111_111
        end
      when ISA::Lui then instruction & 0b1111111111
      else 0u16
      end
      self.new opcode, reg_a, reg_b, reg_c, immediate
    end
    
  end
end
