struct Stacklang::ThreeAddressCode::Translator
  def translate_literal(expression : AST::Literal) : {Address, Type}
    {Immediate.new(expression.number, expression), Type::Word.new}
  end
end
