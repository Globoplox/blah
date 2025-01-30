struct Stacklang::ThreeAddressCode::Translator
  def translate_add(expression : AST::Binary) : {Address, Type}
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

    typeinfo = case {left_typeinfo, right_typeinfo}
               when {Type::Word, Type::Word}    then Type::Word.new
               when {Type::Word, Type::Pointer} then right_typeinfo
               when {Type::Pointer, Type::Word} then left_typeinfo
               else                                  raise Exception.new "Cannot add values of types #{left_typeinfo} and #{right_typeinfo}", expression, @function
               end

    t0 = anonymous 1
    @tacs << Add.new left_address, right_address, t0, expression
    {t0, typeinfo}
  end
end
