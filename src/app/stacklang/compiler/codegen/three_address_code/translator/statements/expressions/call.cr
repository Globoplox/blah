struct Stacklang::ThreeAddressCode::Translator
  def translate_call(expression : AST::Call) : {Address, Type}?
    called_function = @function.unit.functions[expression.name.name]?
    unless called_function
      @events.error(title: "Unknown function", line: expression.token.line, column: expression.token.character) do |io|
        io << "No function named '#{@events.emphasis(expression.name)}' found"
      end
      return
    end

    if expression.parameters.size != called_function.parameters.size
      @events.error(title: "Bad parameters", line: expression.token.line, column: expression.token.character) do |io|
        io << "Function '#{@events.emphasis(expression.name)}' require #{called_function.parameters.size} parameters but has been given #{expression.parameters.size}"
      end
      return
    end

    parameters_and_offsets = expression.parameters.zip(called_function.parameters).map do |parameter, definition|
      target = translate_expression parameter
      unless target
        @events.error(title: "Expression for parameter '#{@events.emphasis(definition.name)}' has no type", line: parameter.token.line, column: parameter.token.character) {}
        return
      end
      address, actual_typeinfo = target
      if actual_typeinfo != definition.constraint
        @events.error(title: "Parameter type error", line: parameter.token.line, column: parameter.token.character) do |io|
          io << "Parameter #{@events.emphasis(definition.name)} of #{@events.emphasis(expression.name)} should be #{@events.emphasis(definition.constraint)} but is a #{@events.emphasis(actual_typeinfo)}"
        end
        return
      end

      {address, definition.offset}
    end

    function_address = Function.new called_function.symbol, expression
    into = called_function.return_type.try { |typeinfo| {anonymous(typeinfo.size.to_i), typeinfo} }
    @tacs << Call.new function_address, into.try(&.[0]), parameters_and_offsets, expression, called_function.return_value_offset
    into
  end

  def translate_binary_to_call(expression : AST::Binary, function_name : String) : {Address, Type}?
    translate_call AST::Call.new(
      token: expression.token,
      name: AST::Identifier.new(expression.token, function_name),
      parameters: [expression.left, expression.right]
    )
  end
end
