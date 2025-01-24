struct Stacklang::ThreeAddressCode::Translator
  def translate_is_not_equal(expression : AST::Binary, jumps : ConditionalJumps)
    # We simply inverse the jumps
    translate_is_equal expression, jumps: ConditionalJumps.new if_true: jumps.if_false, if_false: jumps.if_true
  end
end