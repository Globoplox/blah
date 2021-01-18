require "./risc16"

module RiSC16

  #not tested yet
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

    def imm_7
      (@instruction & 0b111111).to_i16 * ((@instruction >> 6) & 1 ? -1 : 0)
    end

    def u_imm_10
      @instruction & 0b1111111111
    end

    def unsigned_cast(i : Int16)
      if i < 0
        (-i).to_u16 | (1 << 15)
      else
        i.to_u16
      end
    end

    def signed_cast(i : UInt16)
      if i >> 15 == 1
        -(i & ~(1 << 15)).to_i16
      else
        i.to_i16
      end
    end

    def step
      @instruction = ram[@pc]
      instruction = @instruction
      opcode = ISA.from_value instruction >> 13
      case opcode
      when ISA::Add then write_reg_a unsigned_cast (reg_b.to_i32 + reg_c.to_i32).to_i16
      when ISA::Addi then write_reg_a unsigned_cast (reg_b.to_i32 + imm_7).to_i16
      when ISA::Nand then write_reg_a ~(reg_b & reg_c)
      when ISA::Lui then write_reg_a u_imm_10 << 6
      when ISA::Sw then ram[reg_b + imm_7] = reg_a
      when ISA::Beq then @pc += imm_7 if reg_a == reg_b
      when ISA::Jalr
        return @halted = true if imm_7 != 0
        write_reg_a = @pc + 1
        @pc = reg_b
      end
      @pc += 1 unless opcode.jalr?
      registers[0] = 0
      @halted
    end

    def dump(io = STDIN)
      io.puts "Next instruction: 0x#{@pc.to_s(base:16).rjust(4, '0')}: 0b#{ram[pc].to_s(base:2).rjust(16, '0')}"
      io.puts "Registers: #{registers.map do |r| "0x" + r.to_s(base:16).rjust(4, '0') end}"
    end
    
  end
end
