struct Stacklang::ThreeAddressCode::Translator
  def translate_dereference(expression : AST::Unary) : {Address, Type}
    target = translate_expression expression.operand
    unless target
      raise Exception.new "Expression has no type", expression.operand, @function
    end
    address, typeinfo = target
    unless typeinfo.is_a? Type::Pointer
      raise Exception.new "Cannot dereference non-pointer type #{typeinfo}", expression.operand, @function
    end
    t0 = anonymous typeinfo.pointer_of.size.to_i
    @tacs << Move.new address, t0, expression
    {t0, typeinfo.pointer_of}
  end
end
