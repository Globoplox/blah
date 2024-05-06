struct Stacklang::ThreeAddressCode::Translator
  def translate_lvalue(expression : AST::Expression) : {Anonymous, Type::Pointer}
    # If identifier => global, symbol, take ref.
    # If access: lvalue left, + offset
    # If *: value right, must be pointer

    case expression
    when AST::Identifier
      
      address, typeinfo = @scope.search(expression.name) || @globals[expression.name]? || raise Exception.new "Identifier #{expression.name} not found in scope", expression, @function
      t0 = anonymous
      @tacs << {Reference.new(address, t0, expression), Type::Pointer.new(typeinfo)}
      {t0, Type::Pointer.new(typeinfo)}

    when AST::Access
      
      address, address_typeinfo = translate_lvalue expression.operand
      typeinfo = address_typeinfo.pointer_of
      unless typeinfo.is_a? Type::Struct
        raise Exception.new "Cannot access field #{expression.field.name} of type #{typeinfo}", expression, @function
      else
        field = typeinfo.fields.find &.name.== expression.field.name
        unless field
          raise Exception.new "No field named #{expression.field.name} in structure #{typeinfo}", expression, @function
        end
        t0 = anonymous
        t1 = anonymous
        @tacs << {Immediate.new(field.offset.to_i, t0, expression.field), Type::Word.new}
        @tacs << {Add.new(address, t0, t1, expression), Type::Pointer.new(field.constraint)}
        {t1, Type::Pointer.new(field.constraint)}
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