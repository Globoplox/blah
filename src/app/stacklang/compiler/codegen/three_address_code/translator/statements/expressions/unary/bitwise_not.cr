struct Stacklang::ThreeAddressCode::Translator
  def translate_bitwise_not(expression : AST::Unary) : {Address, Type}?
    target = translate_expression expression.operand
    unless target
      @events.error(title: "Expression has no type", line: expression.operand.token.line, column: expression.operand.token.character) {}
      return
    end
    address, typeinfo = target
    if typeinfo != Type::Word.new
      @events.error(title: "Type error", line: expression.operand.token.line, column: expression.operand.token.character) do |io|
        io << "Cannot apply unary operand #{@events.emphasis(expression.name)} on non word type #{@events.emphasis(typeinfo.to_s)}"
      end
      return
    end
    t0 = anonymous 1.to_i
    @tacs << Nand.new address, address, t0, expression
    {t0, Type::Word.new}
  end
end
