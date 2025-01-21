struct Stacklang::ThreeAddressCode::Translator
  def translate_identifier(expression : AST::Identifier) : {Address, Type}
    address, typeinfo = @scope.search(expression.name) || @globals[expression.name]? || raise Exception.new "Identifier #{expression.name} not found in scope", expression, @function
    {address, typeinfo}
  end
end
