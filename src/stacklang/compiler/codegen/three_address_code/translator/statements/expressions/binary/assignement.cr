struct Stacklang::ThreeAddressCode::Translator
  def translate_assignment(expression : AST::Binary) : {Address, Type}    
    right = translate_expression expression.right
    if right.nil?
      raise Exception.new "Expression has no type", expression.right, @function
    end

    right_address, right_typeinfo = right

    left_address, left_typeinfo = translate_lvalue expression.left

    if left_typeinfo != right_typeinfo
      raise Exception.new "Cannot assign value of type #{right_typeinfo} to lvalue of type #{left_typeinfo}", expression, @function
    end

    if right_typeinfo.size > 1
      raise Exception.new "Assignment of complex types is not supported yet", expression, @function
    end

    @tacs << {Move.new(right_address, left_address, expression), right_typeinfo}

    {right_address, right_typeinfo}
  end
end
  