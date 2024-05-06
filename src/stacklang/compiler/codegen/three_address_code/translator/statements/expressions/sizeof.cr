struct Stacklang::ThreeAddressCode::Translator
  def translate_sizeof(expression : AST::Sizeof) : {Anonymous, Type}?
    t0 = anonymous
    @tacs << {Immediate.new(@function.unit.typeinfo(expression.constraint).size.to_i32, t0, expression), Type::Word.new}
    {t0, Type::Word.new}
  end
end
