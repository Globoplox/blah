require "./assembler"
require "./parser"

# Represent an instruction in the program.
class RiSC16::Assembler::Instruction < RiSC16::Instruction
  include Statement
  property complex_immediate : Complex? = nil
  
  def self.parse(operation : ISA, parameters): self
    case operation
    in ISA::Add, ISA::Nand
      a,b,c = Assembler.parse_rrr parameters
      Instruction.new operation, reg_a: a, reg_b: b, reg_c: c
    in ISA::Addi, ISA::Sw, ISA::Lw, ISA::Beq
      a,b,i = Assembler.parse_rri parameters
      Instruction.new operation, reg_a: a, reg_b: b, complex_immediate: i
    in ISA::Lui
      a,i = Assembler.parse_ri parameters
      Instruction.new operation, reg_a: a, complex_immediate: i
    in ISA::Jalr
      a,b,i = Assembler.parse_rri parameters, no_i: true
      Instruction.new operation, reg_a: a, reg_b: b
    end
  end
  
  def initialize(@op : ISA, @reg_a : UInt16 = 0_u16, @reg_b : UInt16 = 0_u16, @reg_c : UInt16 = 0_u16, @immediate : UInt16 = 0_u16, @complex_immediate : Complex? = nil)
  end
  
  def solve(base_address, indexes)
    @immediate = @complex_immediate.try(&.solve(indexes, bits: (@op.lui? ? 10 : 7), relative_to: (@op.beq? ? base_address : nil))) || @immediate
  end
  
  def write(io)
    encode.to_io io, IO::ByteFormat::BigEndian
  end
  
  def stored
    1u16
  end
  
end
