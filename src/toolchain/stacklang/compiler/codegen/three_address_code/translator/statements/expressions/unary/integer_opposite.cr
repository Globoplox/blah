struct Stacklang::ThreeAddressCode::Translator
  def translate_integer_opposite(expression : AST::Unary) : {Address, Type}?
    target = translate_expression expression.operand
    unless target
      @events.error(title: "Expression has no type", line: expression.operand.token.line, column: expression.operand.token.character) {}
      return
    end
    address, actual_typeinfo = target
    if actual_typeinfo != Type::Word.new
      @events.error(title: "Type error", line: expression.operand.token.line, column: expression.operand.token.character) do |io|
        io << "Cannot apply unary operand #{@events.emphasis(expression.name)} on non word type #{@events.emphasis(actual_typeinfo.to_s)}"
      end
      return
    end
    t0 = anonymous 1
    @tacs << Nand.new address, address, t0, expression
    t1 = anonymous 1
    @tacs << Add.new t0, Immediate.new(1, expression), t1, expression
    {t1, Type::Word.new}
  end
end
