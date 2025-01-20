struct Stacklang::ThreeAddressCode::Translator
  def translate_access(expression : AST::Access) : {Address, Type}
    # TODO: we want more than the lvalue, must compute it actually
    address, typeinfo = translate_lvalue expression
    if address.is_a?(Local) || address.is_a?(Global)
      {address, typeinfo}
    else
      t0 = anonymous typeinfo.size.to_i
      @tacs << Move.new address, t0, expression
      {t0, typeinfo}
    end
  end
end
