struct Stacklang::ThreeAddressCode::Translator
  def translate_inferior_equal_to(expression : AST::Binary, jumps : ConditionalJumps)
    translate_inferior_to expression, jumps, or_equal: true
  end
end
