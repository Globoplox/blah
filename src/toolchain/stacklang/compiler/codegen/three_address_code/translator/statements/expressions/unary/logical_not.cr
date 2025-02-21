struct Stacklang::ThreeAddressCode::Translator
  def translate_logical_not(expression : AST::Unary, jumps : ConditionalJumps)
    # We simply inverse the jumps
    translate_conditional expression.operand, jumps: ConditionalJumps.new if_true: jumps.if_false, if_false: jumps.if_true
  end
end
