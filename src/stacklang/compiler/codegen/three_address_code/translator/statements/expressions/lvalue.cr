struct Stacklang::ThreeAddressCode::Translator
  
  def translate_lvalue(expression : AST::Expression) : {Address, Type}
    case expression
    when AST::Identifier
      t0 = anonymous 1

      local = @scope.search(expression.name)
      if local
        address, typeinfo = local 
        @tacs << Reference.new address, t0, expression
        return {t0, Type::Pointer.new typeinfo}
      end

      global = @globals[expression.name]?
      global || raise Exception.new "Identifier #{expression.name} not found in scope", expression, @function
      address, typeinfo = global 
      @tacs << Reference.new address, t0, expression
      return {t0, Type::Pointer.new typeinfo}
      
    when AST::Access
      # TODO maybe:
      # instead of, Ref then Add, 
      # We can actually produce the offset address (local, global, whatever) and make a ref of it.

      
      address, typeinfo = translate_lvalue expression.operand
      typeinfo = typeinfo.pointer_of

      unless typeinfo.is_a? Type::Struct
        raise Exception.new "Cannot access field #{expression.field.name} of type #{typeinfo}", expression, @function
      else
        field = typeinfo.fields.find &.name.== expression.field.name
        unless field
          raise Exception.new "No field named #{expression.field.name} in structure #{typeinfo}", expression, @function
        end

        t0 = anonymous 1
        @tacs << Add.new address, Immediate.new(field.offset.to_i,  expression), t0, expression
        {t0, Type::Pointer.new field.constraint}
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