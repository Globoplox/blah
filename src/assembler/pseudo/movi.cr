require "./pseudo"

# TODO: if offset & 01111111 == 0 then the addi part is useless and it can be omitted.
# But predicting it before solving is annoying.
class RiSC16::Assembler::Pseudo::Movi < RiSC16::Assembler::Pseudo
  property parameters : String
  
  def initialize(@parameters) end
  
  def stored
    2u16
  end
  
  def solve(base_address, indexes)
    a,immediate = Assembler.parse_ri parameters
    offset = immediate.solve indexes, bits: 16
    @instructions = [
      Instruction.new(ISA::Lui, reg_a: a, immediate: offset >> 6),
      Instruction.new(ISA::Addi, reg_a: a, reg_b: a, immediate: offset & 0x3f_u16)
    ]
  end
end
