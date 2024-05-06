struct Stacklang::ThreeAddressCode::Translator
  def translate_literal(expression : AST::Literal) : {Anonymous, Type}
    t0 = anonymous
    @tacs << {Immediate.new(expression.number, t0, expression), Type::Word.new}
    {t0, Type::Word.new}
  end
end
