struct Stacklang::ThreeAddressCode::Translator
  def translate_assignment(expression : AST::Binary) : {Address, Type}    
    right = translate_expression expression.right
    if right.nil?
      raise Exception.new "Expression has no type", expression.right, @function
    end
    right_address, right_typeinfo = right

    # a = b is not the same as *a = b (first is a move, second is a store)
    if expression.left.as?(AST::Unary).try(&.name.== "*")
      operand = expression.left.as(AST::Unary).operand
      left = translate_expression operand
      if left.nil?
        raise Exception.new "Expression has no type", expression.left, @function
      end
      left_address, left_typeinfo = left

      unless left_typeinfo.is_a? Type::Pointer
        raise Exception.new "Cannot dereference non-pointer type #{left_typeinfo}", operand, @function
      end
      left_typeinfo = left_typeinfo.pointer_of

      if left_typeinfo != right_typeinfo
        raise Exception.new "Cannot assign value of type #{right_typeinfo} to lvalue of type #{left_typeinfo}", expression, @function
      end
  
      if right_typeinfo.size > 1
        raise Exception.new "Assignment of complex types is not supported yet", expression, @function
      end

      @tacs << Store.new left_address, right_address, expression

    else
      left = translate_expression expression.left
      if left.nil?
        raise Exception.new "Expression has no type", expression.left, @function
      end
      left_address, left_typeinfo = left
  
      if left_typeinfo != right_typeinfo
        raise Exception.new "Cannot assign value of type #{right_typeinfo} to lvalue of type #{left_typeinfo}", expression, @function
      end
  
      if right_typeinfo.size > 1
        raise Exception.new "Assignment of complex types is not supported yet", expression, @function
      end

      @tacs << Move.new right_address, left_address,expression
    end

    {right_address, right_typeinfo}
  end
end
  
