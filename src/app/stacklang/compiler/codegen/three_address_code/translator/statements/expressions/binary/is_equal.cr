struct Stacklang::ThreeAddressCode::Translator
  def translate_is_equal(expression : AST::Binary, jumps : ConditionalJumps)
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

    unless left_typeinfo == right_typeinfo || ((left_typeinfo.is_a?(Type::Word) || left_typeinfo.is_a?(Type::Pointer)) && (right_typeinfo.is_a?(Type::Word) || right_typeinfo.is_a?(Type::Pointer)))
      @events.error(title: "Type error", line: expression.token.line, column: expression.token.character) do |io|
        io << "Cannot compare values of types #{@events.emphasis(left_typeinfo)} and #{@events.emphasis(right_typeinfo)}"
      end
      return
    end

    # if equal, jump to true
    @tacs << JumpEq.new(jumps.if_true, {left_address, right_address}, expression)
    # otherwise jump to false
    @tacs << JumpEq.new(jumps.if_false, nil, expression)
  end
end
