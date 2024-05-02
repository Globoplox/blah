struct Stacklang::ThreeAddressCode::Translator
    def translate_call(expression : AST::Call) : {Address, Type}?
    function = @unit.functions[expression.name]?
    unless function
        raise Exception.new "Identifier: '#{expression.name}' does not refer to any known function name", expression, @function
    end

    unless expression.parameters.size != function.parameters.size
        raise Exception.new "Function #{expression.name} require #{function.parameters.size} but has been give #{expression.parameters.size}", expression, @function
    end

    parameters = expression.parameters.zip(function.parameters).map do |parameter, definition|
        target = translate_expression parameter
        unless target 
        raise Exception.new "Expression has no type", parameter, @function
        end
        address, actual_typeinfo = target 
        if actual_typeinfo != definition.constraint 
        raise Exception.new "Parameter #{definition.name} of #{expression.name} should be #{definition.constraint} but is a #{actual_typeinfo}", expression, @function
        end
        address
    end

    entry = function.return_type.try { |typeinfo| ({anonymous, typeinfo}) } 
    tac = Call.new expression.name.name, parameters, entry.try(&.[0]), expression
    @tacs << {tac, function.return_type}
    entry
     
end
end