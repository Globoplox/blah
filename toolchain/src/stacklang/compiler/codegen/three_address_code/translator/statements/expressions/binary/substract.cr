struct Stacklang::ThreeAddressCode::Translator
  def translate_substract(expression : AST::Binary) : {Address, Type}?
    left = translate_expression expression.left
    if left.nil?
      @events.error(title: "Expression has no type", line: expression.left.token.line, column: expression.left.token.character) {}
      return
    end

    right = translate_expression expression.right
    if right.nil?
      @events.error(title: "Expression has no type", line: expression.right.token.line, column: expression.right.token.character) {}
      return
    end

    left_address, left_typeinfo = left
    right_address, right_typeinfo = right

    typeinfo = case {left_typeinfo, right_typeinfo}
    when {Type::Word, Type::Word}    then Type::Word.new
    when {Type::Word, Type::Pointer} then right_typeinfo
    when {Type::Pointer, Type::Word} then left_typeinfo
    else 
      @events.error(title: "Type error", line: expression.token.line, column: expression.token.character) do |io|
        io << "Cannot substract values of types #{@events.emphasis(left_typeinfo)} and #{@events.emphasis(right_typeinfo)}"
      end
    return 
    end

    t0 = anonymous 1
    @tacs << Nand.new right_address, right_address, t0, expression
    t1 = anonymous 1
    @tacs << Add.new t0, Immediate.new(1, expression), t1, expression

    t2 = anonymous 1
    @tacs << Add.new left_address, t1, t2, expression
    {t2, typeinfo}
  end
end
