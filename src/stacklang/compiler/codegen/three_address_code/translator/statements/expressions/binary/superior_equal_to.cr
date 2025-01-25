struct Stacklang::ThreeAddressCode::Translator
  def translate_superior_equal_to(expression : AST::Binary, jumps : ConditionalJumps)
    translate_inferior_to expression, jumps: jumps, or_equal: true, inverse: true
  end
end