struct Stacklang::ThreeAddressCode::Translator
  def translate_call(expression : AST::Call) : {Address, Type}?
    called_function = @function.unit.functions[expression.name.name]?
    unless called_function
      raise Exception.new "Identifier: '#{expression.name}' does not refer to any known function name", expression, @function
    end

    if expression.parameters.size != called_function.parameters.size
      raise Exception.new "Function #{expression.name} require #{called_function.parameters.size} parameters but has been given #{expression.parameters.size} parameters", expression, @function
    end

    parameters_and_offsets = expression.parameters.zip(called_function.parameters).map do |parameter, definition|
      target = translate_expression parameter
      unless target
        raise Exception.new "Expression has no type", parameter, @function
      end
      address, actual_typeinfo = target
      if actual_typeinfo != definition.constraint
        raise Exception.new "Parameter #{definition.name} of #{expression.name} should be #{definition.constraint} but is a #{actual_typeinfo}", expression, @function
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
