struct Stacklang::ThreeAddressCode::Translator
  def translate_integer_opposite(expression : AST::Unary) : {Address, Type}
    target = translate_expression expression.operand
    unless target
      raise Exception.new "Expression has no type", expression.operand, @function
    end
    address, actual_typeinfo = target
    if actual_typeinfo != Type::Word.new
      raise Exception.new "Cannot apply unary operand #{expression.name} on non word type #{actual_typeinfo}", expression.operand, @function
    end
    t0 = anonymous 1
    @tacs << {Nand.new(address, address, t0, expression), Type::Word.new}
    t1 = anonymous 1
    @tacs << {Add.new(t0, Immediate.new(1,  expression), t1, expression), Type::Word.new}    
    {t1, Type::Word.new}
  end
end
