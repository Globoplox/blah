struct Stacklang::ThreeAddressCode::Translator
  def translate_sizeof(expression : AST::Sizeof) : {Address, Type}
    {Immediate.new(@function.unit.typeinfo(expression.constraint).size.to_i32, expression), Type::Word.new}
  end
end
