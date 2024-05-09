struct Stacklang::ThreeAddressCode::Translator
  def translate_access(expression : AST::Access) : {Address, Type}
    address, typeinfo = translate_lvalue expression
    if address.is_a?(Local) || address.is_a?(Global)
      {address, typeinfo}
    else
      t0 = anonymous typeinfo.size.to_i
      @tacs << {Move.new(address, t0, expression), typeinfo}
      {t0, typeinfo}
    end
  end
end
