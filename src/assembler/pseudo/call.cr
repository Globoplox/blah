require "./pseudo"

# call :function r7 r1 r2 r6
# Will save r1 and r2 on stack beginning at r7 and store return value in r6
class RiSC16::Assembler::Pseudo::Call < RiSC16::Assembler::Pseudo

  @stack_register : Word
  @call_register : Word
  @param_registers : Array(Word)
  @target : Complex
  
  def initialize(parameters)
    parameters = parameters.split /\s+/, remove_empty: true
    raise "Unexpected call parameters amount: found #{parameters.size}, expected at least 3" if parameters.size < 3
    @target = Assembler.parse_immediate parameters.first
    registers = parameters[1..]
    registers = registers.map do |register| register.lchop?('r') || register end.map(&.to_u16)
    @stack_register = registers.first
    @call_register = registers.last
    @param_registers = registers[1..(-2)]
  end
  
  def stored
    6u16 + @param_registers.size * 2
  end
  
  def solve(base_address, indexes)
    # store parameters in stack
    @param_registers.each_with_index do |param, index|
      @instructions << Instruction.new ISA::Sw, reg_a: param, reg_b: @stack_register, immediate: index == 0 ? 0u16 : MAX_IMMEDIATE - index
    end
    # Move the stack after the parameters
    @instructions << Instruction.new ISA::Addi, reg_a: @stack_register, reg_b: @stack_register, immediate: MAX_IMMEDIATE - (@param_registers.size)
    # load the callpoint address in the call register
    offset = @target.solve indexes, bits: 16
    @instructions << Instruction.new ISA::Lui, reg_a: @call_register, immediate: offset >> 6
    @instructions << Instruction.new ISA::Addi, reg_a: @call_register, reg_b: @call_register, immediate: offset & 0x3f_u16
    # jump to call site
    @instructions << Instruction.new ISA::Jalr, reg_a: @call_register, reg_b: @call_register, immediate: 0u16
    # ... call is performed
    # when returning
    # fetch the return value 
    @instructions << Instruction.new ISA::Lw, reg_a: @call_register, reg_b: @stack_register, immediate: 1u16
    # restore saved registers
    @param_registers.each_with_index do |param, index|
      @instructions << Instruction.new ISA::Lw, reg_a: param, reg_b: @stack_register, immediate: 1u16 + index
    end
    @instructions << Instruction.new ISA::Addi, reg_a: @stack_register, reg_b: @stack_register, immediate: @param_registers.size.to_u16 + 1
  end
end
