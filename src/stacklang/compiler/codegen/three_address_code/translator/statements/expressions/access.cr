struct Stacklang::ThreeAddressCode::Translator

    def translate_access(expression : AST::Access) : {Address, Type}?
        target = translate_expression expression.operand
        unless target
            raise Exception.new "Expression has no type", expression, @function
        end

        address, typeinfo = target

        unless typeinfo.is_a? Type::Struct
            raise Exception.new "Cannot access field #{expression.field.name} of type #{typeinfo}", expression, @function
        else
            field = typeinfo.fields.find &.name.== expression.field.name
            unless field
            raise Exception.new "No field named #{expression.field.name} in structure #{typeinfo}", expression, @function
            end
            t0 = anonymous
            t1 = anonymous
            t2 = anonymous
            @tacs << {Reference.new(address, t0, expression), Type::Pointer.new(typeinfo)}
            @tacs << {Add.new(t0, Literal.new(field.offset.to_i, expression.field), t1, expression), Type::Pointer.new(field.constraint)}
            @tacs << {DereferenceRight.new(t1, t2, expression), field.constraint}
            {t2, field.constraint}
        end
    end
end