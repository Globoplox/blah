struct Stacklang::ThreeAddressCode::Translator
  def translate_logical_or(expression : AST::Binary, jumps : ConditionalJumps)
    continue = "__log_or_#{next_uid}"
    translate_conditional expression.left, jumps: ConditionalJumps.new if_true: jumps.if_true, if_false: continue
    @tacs << Label.new continue, expression
    translate_conditional expression.right, jumps: ConditionalJumps.new if_true: jumps.if_true, if_false: jumps.if_false
  end
end