require "./pseudo"

class RiSC16::Assembler::Pseudo::Lli < RiSC16::Assembler::Pseudo
  property parameters : String
  
  def initialize(@parameters) end
  
  def stored
    1u16
  end
  
  def solve(base_address, indexes)
    a,immediate = Assembler.parse_ri parameters
    offset = immediate.solve indexes, bits: 16
    @instructions = [Instruction.new ISA::Addi, reg_a: a, reg_b: a, immediate: offset & 0x3f_u16]
  end
end
