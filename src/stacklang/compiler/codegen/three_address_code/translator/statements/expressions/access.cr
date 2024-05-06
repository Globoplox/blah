struct Stacklang::ThreeAddressCode::Translator
  def translate_access(expression : AST::Access) : {Anonymous, Type}
    address, typeinfo = translate_lvalue expression
    t0 = anonymous
    @tacs << {Load.new(address, t0, expression), typeinfo.pointer_of}
    {t0, typeinfo.pointer_of}
  end
end
