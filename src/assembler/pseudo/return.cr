require "./pseudo"

# return r7 r4 r6
# return with value r4 to return address in stack (r7) using the r6 temporary register. 
class RiSC16::Assembler::Pseudo::Return < RiSC16::Assembler::Pseudo
  @stack_register : Word
  @return_register : Word
  @call_register : Word
  
  def initialize(parameters)
    registers = parameters.split /\s+/, remove_empty: true
    raise "Unexpected return parameters amount: found #{registers.size}, expected 3" unless registers.size == 3
    registers = registers.map do |register| register.lchop?('r') || register end.map(&.to_u16) 
    @stack_register = registers.first
    @return_register = registers[1]
    @call_register = registers.last
  end
  
  def stored
    3u16
  end
  
  def solve(base_address, indexes)
    # fetch the return address in tmp register
    @instructions << Instruction.new ISA::Lw, reg_a: @call_register, reg_b: @stack_register, immediate: 1u16
    # write the return value in stack
    @instructions << Instruction.new ISA::Sw, reg_a: @return_register, reg_b: @stack_register, immediate: 1u16
    # Jump to return address
    @instructions << Instruction.new ISA::Jalr, reg_a: 0u16, reg_b: @call_register, immediate: 0u16
  end
end
