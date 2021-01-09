require "./risc16"

module RiSC16

  #not tested yet
  class VM

    DEFAULT_RAM_SIZE = MAX_MEMORY_SIZE
    
    property ram : Array(UInt16)
    property registers = Array(UInt16).new REGISTER_COUNT
    property pc = 0
    
    def initialize(ram_size)
      @ram = Array(UInt16).new ram_size
    end
    
    def load(program, at = 0)
      program.each_byte do |byte|
        ram[at] = byte
        at += 1
      end
    end

    def step
      instruction = ram[@pc]
      opcode = ISA.from_value instruction >> 13
      case opcode
      when Add then registers[(instruction >> 10) & 0b111] = regsiters[(instruction >> 7) & 0b111] + registers[instruction 0b111]
      when Addi then registers[(instruction >> 10) & 0b111] = regsiters[(instruction >> 7) & 0b111] + (instruction & 0b111111) * ((instruction >> 6) & 1 ? -1 : 0)
      when Nand then registers[(instruction >> 10) & 0b111] = ~(regsiters[(instruction >> 7) & 0b111] & registers[instruction 0b111])
      when Lui then registers[(instruction >> 10) & 0b111] = (instruction & 0b1111111111) << 6
      when Sw then ram[regsiters[(instruction >> 7) & 0b111] + (instruction & 0b111111) * ((instruction >> 6) & 1 ? -1 : 0)] = registers[(instruction >> 10) & 0b111]
      when Beq then @pc += (instruction & 0b111111) * ((instruction >> 6) & 1 ? -1 : 0) if regsiters[(instruction >> 10) & 0b111] == regsiters[(instruction >> 7) & 0b111]
      when Jalr
        registers[(instruction >> 10) & 0b111] = @pc + 1
        @pc = regsiters[(instruction >> 7) & 0b111]
      end
      @pc += 1 unless opcode.jalr?
      registers[0] = 0
    end
  end
end
