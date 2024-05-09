struct Stacklang::ThreeAddressCode::Translator
  def translate_lvalue(expression : AST::Expression) : {Address, Type}
    # If identifier => global, symbol, take ref.
    # If access: lvalue left, + offset
    # If *: value right, must be pointer

    # TODO: return either a anonymous and ptr OR (local OR global) + real type

    case expression
    when AST::Identifier
      
      address, typeinfo = @scope.search(expression.name) || @globals[expression.name]? || raise Exception.new "Identifier #{expression.name} not found in scope", expression, @function
      {address, typeinfo}

    when AST::Access
      
      address, typeinfo = translate_lvalue expression.operand
      unless typeinfo.is_a? Type::Struct
        raise Exception.new "Cannot access field #{expression.field.name} of type #{typeinfo}", expression, @function
      else
        field = typeinfo.fields.find &.name.== expression.field.name
        unless field
          raise Exception.new "No field named #{expression.field.name} in structure #{typeinfo}", expression, @function
        end
        if address.is_a? (Local) || address.is_a?(Global)
          address.offset += field.offset.to_i
          address.size = field.constraint.size.to_i
          {address, field.constraint}
        else
          t0 = anonymous field.constraint.size.to_i
          @tacs << {Add.new(address, Immediate.new(field.offset.to_i, expression.field), t0, expression), Type::Pointer.new(field.constraint)}
          {t0, field.constraint}
        end
      end
      
    when AST::Unary
      case expression.name
      when "*"
        
        target = translate_expression expression.operand
        unless target
          raise Exception.new "Expression has no type", expression.operand, @function
        end
        address, typeinfo = target
        unless typeinfo.is_a? Type::Pointer
          raise Exception.new "Expected pointer type, got non-pointer type #{typeinfo}", expression.operand, @function
        end
        {address, typeinfo}

      else raise Exception.new "Cannot compute LValue for Unary operator '#{expression.name}'", expression, @function
      end
    
    else raise Exception.new "Cannot compute LValue for node '#{expression.class.name}'", expression, @function
    end
  
  end
end