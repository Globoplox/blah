struct Stacklang::ThreeAddressCode::Translator
  def translate_cast(expression : AST::Cast) : {Address, Type}?
    target = translate_expression(expression.target)
    unless target
      @events.error(title: "Cannot cast expression with no value or type", line: expression.token.line, column: expression.token.character) {}              
      return
    end
    address, typeinfo = target
    {address, @function.unit.typeinfo(expression.constraint)}
  end
end
