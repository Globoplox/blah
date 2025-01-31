struct Stacklang::ThreeAddressCode::Translator
  def translate_dereference(expression : AST::Unary) : {Address, Type}?
    target = translate_expression expression.operand
    unless target
      @events.error(title: "Expression has no type", line: expression.operand.token.line, column: expression.operand.token.character) {}
      return
    end
    address, typeinfo = target
    unless typeinfo.is_a? Type::Pointer
      @events.error(title: "Type error", line: expression.operand.token.line, column: expression.operand.token.character) do |io|
        io << "Cannot dereference non-pointer type #{@events.emphasis(typeinfo.to_s)}"
      end
      return
    end
    t0 = anonymous typeinfo.pointer_of.size.to_i
    @tacs << Load.new address, t0, expression
    {t0, typeinfo.pointer_of}
  end
end
