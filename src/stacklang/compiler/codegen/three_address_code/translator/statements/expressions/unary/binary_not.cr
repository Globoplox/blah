struct Stacklang::ThreeAddressCode::Translator
  def translate_binary_not(expression : AST::Unary) : {Address, Type}
    target = translate_expression expression.operand
    unless target
      raise Exception.new "Expression has no type", expression.operand, @function
    end
    address, typeinfo = target
    if typeinfo != Type::Word.new
      raise Exception.new "Cannot apply unary operand #{expression.name} on non word type #{typeinfo}", expression.operand, @function
    end
    t0 = anonymous 1.to_i
    @tacs << {Nand.new(address, address, t0, expression), Type::Word.new}
    {t0, Type::Word.new}
  end
end
