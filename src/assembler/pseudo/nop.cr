require "./pseudo"

class RiSC16::Assembler::Pseudo::Nop < RiSC16::Assembler::Pseudo

  def initialize(parameters) end
  
  def stored
    1u16
  end
  
  def solve(base_address, indexes)
    @instructions = [Instruction.new ISA::Add, reg_a: 0_u16 ,reg_b: 0_u16, reg_c: 0_u16]
  end

end
