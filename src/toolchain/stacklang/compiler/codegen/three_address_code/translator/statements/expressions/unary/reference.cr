struct Stacklang::ThreeAddressCode::Translator
  def translate_reference(expression : AST::Unary) : {Address, Type}?
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
      ref = translate_access operand
      unless ref
        @events.error(title: "Expression has no type", line: operand.token.line, column: operand.token.character) {}
        return
      end

      address, typeinfo = ref

      if typeinfo.is_a? Type::Table
        typeinfo = typeinfo.table_of
      end

      @tacs << Reference.new address, t0, expression
      {t0, Type::Pointer.new typeinfo}
      # Note that if the root of this access is not an identifier or a dereferencement,
      # this is invalid and allows to actually access temporary values

    when AST::Unary
      case expression.name
      when "*"
        target = translate_expression expression.operand
        unless target
          @events.error(title: "Expression has no type", line: operand.token.line, column: operand.token.character) {}
          return
        end
        address, typeinfo = target

        if typeinfo.is_a? Type::Table
          typeinfo = typeinfo.table_of
        end

        unless typeinfo.is_a? Type::Pointer
          @events.error(title: "Type error", line: operand.token.line, column: operand.token.character) do |io|
            io << "Expected pointer type, got non-pointer type: #{@events.emphasis(typeinfo)}"
          end
          return
        end
        {address, typeinfo}
      else 
        @events.error(title: "LValue error", line: operand.token.line, column: operand.token.character) do |io|
          io << "Cannot compute LValue for unary operation with operator '#{@events.emphasis(expression.name)}'"
        end
        return      
      end
    else
      @events.error(title: "LValue error", line: operand.token.line, column: operand.token.character) do |io|
        io << "Cannot compute LValue for expression of type '#{@events.emphasis(expression.class.name)}'"
      end
      return    
    end
  end
end
