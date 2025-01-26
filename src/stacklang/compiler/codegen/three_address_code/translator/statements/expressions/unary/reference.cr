struct Stacklang::ThreeAddressCode::Translator
  def translate_reference(expression : AST::Unary) : {Address, Type}
    operand = expression.operand
    case operand
    when AST::Identifier
      t0 = anonymous 1
      address, typeinfo = translate_identifier operand

      if typeinfo.is_a? Type::Table
        typeinfo = typeinfo.table_of
      end

      @tacs << Reference.new address, t0, expression
      {t0, Type::Pointer.new typeinfo}
    when AST::Access
      t0 = anonymous 1
      address, typeinfo = translate_access operand

      if typeinfo.is_a? Type::Table
        typeinfo = typeinfo.table_of
      end

      @tacs << Reference.new address, t0, expression
      {t0, Type::Pointer.new typeinfo}
      # Note that if the root of this access is not an identifier or a dereferencement,
      # this is invalid and allows to actually right temporary values

    when AST::Unary
      case expression.name
      when "*"
        target = translate_expression expression.operand
        unless target
          raise Exception.new "Expression has no type", expression.operand, @function
        end
        address, typeinfo = target

        if typeinfo.is_a? Type::Table
          typeinfo = typeinfo.table_of
        end

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
