class Stacklang::Function

  # Compile a call. This cause all variable cached in registers to be stacked.
  def compile_call(call : AST::Call, into : Registers | Memory | Nil): Type::Any
    function = @unit.functions[call.name.name]? || error "Unknown functions '#{call.name.name}'", node: call
    if function.prototype.parameters.size != call.parameters.size                                                      
      error "Call to #{function.name} require #{function.prototype.parameters.size} paremters but #{call.parameters.size} given", node: call
    end  
    tmp_offset = @temporaries.size
    function.prototype.parameters.each_with_index do |parameter, index|
      actual_type = compile_expression call.parameters[index], into: Memory.offset parameter.offset - tmp_offset
      if parameter.constraint != actual_type
        error "Parameter #{parameter.name} of #{function.name} should be #{parameter.constraint} but is #{actual_type}", node: call
      end
    end
    store_all
    @text << Instruction.new(ISA::Addi, STACK_REGISTER.value, STACK_REGISTER.value, immediate: assemble_immediate -tmp_offset, Kind::Imm).encode if tmp_offset != 0
    @text << Instruction.new(ISA::Lui, RETURN_ADRESS_REGISTER.value, immediate: assemble_immediate function.prototype.symbol, Kind::Lui).encode
    @text << Instruction.new(
      ISA::Addi, RETURN_ADRESS_REGISTER.value, RETURN_ADRESS_REGISTER.value, immediate: assemble_immediate function.prototype.symbol, Kind::Lli
    ).encode
    @text << Instruction.new(ISA::Jalr, RETURN_ADRESS_REGISTER.value, RETURN_ADRESS_REGISTER.value).encode
    @text << Instruction.new(ISA::Addi, STACK_REGISTER.value, STACK_REGISTER.value, immediate: assemble_immediate tmp_offset, Kind::Imm).encode if tmp_offset != 0
    into.try do |destination|
      return_type = function.prototype.return_type
      error "Cannot use return value of call to function '#{function.name}' with no return value" if return_type.nil?
      move Memory.offset(function.prototype.return_value_offset.not_nil! - tmp_offset), return_type, into: destination 
    end
    function.prototype.return_type || Type::Word.new
    # We cheat: if here is no into, there won't be type check. And if return_type is nil and there is an into we raise.
    # So we can safely return bullshit if there are no function.prototype.return_type.
  end
  
end
