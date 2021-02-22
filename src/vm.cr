require "./risc16"

module RiSC16

  class VM

    DEFAULT_RAM_SIZE = MAX_MEMORY_SIZE
    
    property ram : Array(UInt16)
    property registers = Array(UInt16).new REGISTER_COUNT, 0_i16
    property pc = 0_u16
    property halted = false
    @instruction = 0_u16
    
    def initialize(ram_size = DEFAULT_RAM_SIZE)
      @ram = Array(UInt16).new ram_size, 0_u16
    end
    
    def load(program, at = 0)
      program.each_byte do |byte|
        ram[at // 2] |= byte.to_u16 << 8 * (at % 2)
        at += 1
      end
    end

    def write_reg_a(v)
      registers[(@instruction >> 10) & 0b111] = v
    end

    def reg_a
      registers[(@instruction >> 10) & 0b111]
    end
    
    def reg_b
      registers[(@instruction >> 7) & 0b111]
    end

    def reg_c
      registers[@instruction & 0b111]
    end

    def imm_10
      @instruction & 0b1111111111
    end

    def imm_7
      if (@instruction & 0b1_000_000 != 0)
        ((2_u32 ** 16) - ((2 ** 7) - (@instruction & 0b1111111))).bits(0...16).to_u16
      else
        @instruction & 0b111_111
      end
    end

    def add(a : UInt16, b : UInt16): UInt16
      (a.to_u32 + b.to_u32).bits(0...16).to_u16
    end      
    
    def step
      @instruction = ram[@pc]
      instruction = @instruction
      opcode = ISA.from_value instruction >> 13
      case opcode
      when ISA::Add then write_reg_a add reg_b, reg_c
      when ISA::Addi then write_reg_a add reg_b, imm_7
      when ISA::Nand then write_reg_a ~(reg_b & reg_c)
      when ISA::Lui then write_reg_a imm_10 << 6
      when ISA::Sw then ram[add reg_b, imm_7] = reg_a
      when ISA::Lw then write_reg_a ram[add reg_b, imm_7]
      when ISA::Beq then @pc = add @pc, imm_7 if reg_a == reg_b
      when ISA::Jalr
        return @halted = true if imm_7 != 0
        write_reg_a = @pc + 1
        @pc = reg_b
      end
      @pc += 1 unless opcode.jalr?
      registers[0] = 0
      @halted
    end    
  end
end
