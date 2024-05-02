struct Stacklang::ThreeAddressCode::Translator
    def translate_identifier(expression : AST::Identifier) : {Address, Type}?
        typeinfo = @context[expression.name]?
        unless typeinfo
            raise Exception.new "Identifier: '#{expression.name}' does not refer to any known symbol", expression, @function
        end
        {Identifier.new(expression.name, expression), typeinfo}

    end
end