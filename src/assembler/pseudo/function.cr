require "./pseudo"

# function r7 r6
# save return address (r6) in stack (r7) 
class RiSC16::Assembler::Pseudo::Function < RiSC16::Assembler::Pseudo
  @stack_register : Word
  @call_register : Word
  
  def initialize(parameters)
    registers = parameters.split /\s+/, remove_empty: true
    raise "Unexpected function parameters amount: found #{registers.size}, expected 2" unless registers.size == 2
    registers = registers.map do |register| register.lchop?('r') || register end.map(&.to_u16)
    @stack_register = registers.first
    @call_register = registers.last
  end
  
  def stored
    1u16
  end
  
  def solve(base_address, indexes)
    # Save the return address on stack, expecting stack to have a reserved space for it
    @instructions << Instruction.new ISA::Sw, reg_a: @call_register, reg_b: @stack_register, immediate: 1u16
  end
end
