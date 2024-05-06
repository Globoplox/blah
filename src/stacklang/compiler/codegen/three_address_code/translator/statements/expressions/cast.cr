struct Stacklang::ThreeAddressCode::Translator
  def translate_cast(expression : AST::Cast) : {Anonymous, Type}
    target = translate_expression(expression.target)
    unless target
      raise Exception.new "Cannot cast expression with no value or type", expression, @function
    end
    address, typeinfo = target
    {address, @function.unit.typeinfo(expression.constraint)}
  end
end
