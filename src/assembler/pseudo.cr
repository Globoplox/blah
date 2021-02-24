require "./assembler"
require "./instruction"
require "./parser"

# Represent a pseudo instruction.
class RiSC16::Assembler::Pseudo
  include Statement
  property operation : PISA
  property parameters : String
  @instructions = [] of Instruction
  
  # Pseudo instruction set
  enum PISA
    Nop
    Halt
    Lli
    Movi
  end
  
  def initialize(@operation, @parameters) end
  
  def stored
    case operation
        in PISA::Nop then 1u16
        in PISA::Halt then 1u16
        in PISA::Lli then 1u16
        in PISA::Movi then 2u16
    end
  end
  
  def solve(base_address, indexes)
    @instructions = case operation
    in PISA::Nop then [Instruction.new ISA::Add, reg_a: 0_u16 ,reg_b: 0_u16, reg_c: 0_u16]
    in PISA::Halt then [Instruction.new ISA::Jalr, reg_a: 0_u16 , reg_b: 0_u16, immediate: 1_u16 ]
    in PISA::Lli
      a,immediate = Assembler.parse_ri parameters
      offset = immediate.solve indexes, bits: 16
      [Instruction.new ISA::Addi, reg_a: a, reg_b: a, immediate: offset & 0x3f_u16 ]
    in PISA::Movi
      # TODO: if offset & 01111111 == 0 then the addi part is useless and it can be omitted.
      a,immediate = Assembler.parse_ri parameters
      offset = immediate.solve indexes, bits: 16
      [Instruction.new(ISA::Lui, reg_a: a, immediate: offset >> 6),
       Instruction.new(ISA::Addi, reg_a: a, reg_b: a, immediate: offset & 0x3f_u16)]
    end
  end
      
  def write(io)
    @instructions.each &.write io
  end
end
