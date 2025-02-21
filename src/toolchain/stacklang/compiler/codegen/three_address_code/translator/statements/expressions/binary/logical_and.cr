struct Stacklang::ThreeAddressCode::Translator
  def translate_logical_and(expression : AST::Binary, jumps : ConditionalJumps)
    continue = "__log_and_#{next_uid}"
    translate_conditional expression.left, jumps: ConditionalJumps.new if_true: continue, if_false: jumps.if_false
    @tacs << Label.new continue, expression
    translate_conditional expression.right, jumps: ConditionalJumps.new if_true: jumps.if_true, if_false: jumps.if_false
  end
end
