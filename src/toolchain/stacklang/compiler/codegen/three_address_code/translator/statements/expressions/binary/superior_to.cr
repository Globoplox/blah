struct Stacklang::ThreeAddressCode::Translator
  def translate_superior_to(expression : AST::Binary, jumps : ConditionalJumps)
    translate_inferior_to expression, jumps: jumps, inverse: true
  end
end
