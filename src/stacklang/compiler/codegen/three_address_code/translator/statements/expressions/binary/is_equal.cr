struct Stacklang::ThreeAddressCode::Translator
  def translate_is_equal(expression : AST::Binary, jumps : ConditionalJumps)
    left = translate_expression expression.left
    if left.nil?
      raise Exception.new "Expression has no type", expression.left, @function
    end

    right = translate_expression expression.right
    if right.nil?
      raise Exception.new "Expression has no type", expression.right, @function
    end

    left_address, left_typeinfo = left
    right_address, right_typeinfo = right

    unless left_typeinfo == right_typeinfo || ((left_typeinfo.is_a?(Type::Word) || left_typeinfo.is_a?(Type::Pointer)) && (right_typeinfo.is_a?(Type::Word) || right_typeinfo.is_a?(Type::Pointer)))
      else raise Exception.new "Cannot compare values of types #{left_typeinfo} and #{right_typeinfo}", expression, @function
    end

    # if equal, jump to true
    @tacs << JumpEq.new(jumps.if_true, {left_address, right_address}, expression)
    # otherwise jump to false
    @tacs << JumpEq.new(jumps.if_false, nil, expression)
  end
end