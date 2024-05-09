struct Stacklang::ThreeAddressCode::Translator
  def translate_reference(expression : AST::Unary) : {Address, Type}
    address, typeinfo = translate_lvalue expression
    {address, typeinfo}
  end
end
