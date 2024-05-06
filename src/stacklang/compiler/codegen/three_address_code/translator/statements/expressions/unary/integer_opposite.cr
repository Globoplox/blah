struct Stacklang::ThreeAddressCode::Translator
  def translate_integer_opposite(expression : AST::Unary) : {Anonymous, Type}
    target = translate_expression expression.operand
    unless target
      raise Exception.new "Expression has no type", expression.operand, @function
    end
    address, actual_typeinfo = target
    if actual_typeinfo != Type::Word.new
      raise Exception.new "Cannot apply unary operand #{expression.name} on non word type #{actual_typeinfo}", expression.operand, @function
    end
    t0 = anonymous
    @tacs << {Nand.new(address, address, t0, expression), Type::Word.new}
    t1 = anonymous
    @tacs << {Immediate.new(1, t1, expression), Type::Word.new}
    t2 = anonymous
    @tacs << {Add.new(t0, t1, t2, expression), Type::Word.new}    
    {t2, Type::Word.new}
  end
end
