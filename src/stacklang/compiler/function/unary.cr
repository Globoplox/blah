class Stacklang::Function


  # Compile unary operator operating on word values.
  def compile_value_unary(unary : AST::Unary, into : Registers | Memory | Nil): Type::Any
    if into.nil? # We optimize to nothing unless operand might have side-effects 
      expression_type = compile_expression unary.operand, into: nil
      error "Cannot apply unary operator '#{unary.name}' to non-word type #{expression_type}", node: unary unless expression_type.is_a? Type::Word
      expression_type
    else
      operand_register = grab_register excludes: into.used_registers # TODO: maybe useless
      expression_type = compile_expression unary.operand, into: operand_register
      error "Cannot apply unary operator '#{unary.name}' to non-word type #{expression_type}", node: unary unless expression_type.is_a? Type::Word
      case unary.name
      when "-"
        result_register = grab_register excludes: [operand_register] + into.used_registers # TODO: still likely useless
        nand result_register, operand_register, operand_register
        addi result_register, result_register, 1
        move result_register, expression_type, into: into
      when "~"
        result_register = grab_register excludes: [operand_register] + into.used_registers # TODO: still likely useless
        nand result_register, operand_register, operand_register
        move result_register, expression_type, into: into
      else error "Unsupported unary operation '#{unary.name}'", node: unary
      end
      expression_type
    end
  end

  # Compile dereferencement expression.
  # It has it's own case instead of being in `#compile_value_unary` to simplify error display. 
  def compile_ptr_unary(operand : AST::Expression, into : Registers | Memory | Nil, node : AST::Node): Type::Any
    if into.nil? # We optimize to nothing unless operand might have side-effects                                                                                            
      expression_type = compile_expression operand, into: nil
      error "Cannot dereference non-pointer type #{expression_type}", node: node unless expression_type.is_a? Type::Pointer
      expression_type.pointer_of
    else
      address_register = grab_register excludes: into.used_registers # TODO: maybe useless                                                                                  
      expression_type = compile_expression operand, into: address_register
      error "Cannot dereference non-pointer type #{expression_type}", node: node unless expression_type.is_a? Type::Pointer
      # We use a temporary var to reuse the dereferencement capability of move                                                                                              
      with_temporary(address_register, expression_type) do |temporary|
        move Memory.absolute(temporary), expression_type.pointer_of, into
      end
      expression_type.pointer_of
    end
  end

  # Compile &() expression.
  def compile_addressable_unary(operand : AST::Expression, into : Registers | Memory | Nil, node : AST::Node): Type::Any
    lvalue_result = compile_lvalue operand
    lvalue_result || error "Expression #{operand.to_s} is not a valid operand for operator '&'", node: node
    lvalue, targeted_type = lvalue_result
    targeted_type = targeted_type.table_of if targeted_type.is_a? Type::Table # TODO: remove this fix to make table usable because there is no cast not table access yet
    ptr_type = Type::Pointer.new targeted_type
    into.try do |destination|
      if lvalue.value.is_a? String || lvalue.value
        offset_register = grab_register excludes: lvalue.used_registers
        # We get the real address in a register, for this we need to movi offset if symbol
        movi offset_register, lvalue
        add offset_register, offset_register, lvalue.reference_register!
        address_register = offset_register
      else
        address_register = lvalue.reference_register!
      end
      move address_register, ptr_type, into: destination
    end
    ptr_type
  end

  # Compile a unary operator value, and move it's value if necessary.
  def compile_any_unary(unary : AST::Unary, into : Registers | Memory | Nil): Type::Any
    case unary.name
    when "&" then compile_addressable_unary unary.operand, into: into, node: unary
    when "*"then compile_ptr_unary unary.operand, into: into, node: unary
    else compile_value_unary unary, into: into
    end
  end
  
end
