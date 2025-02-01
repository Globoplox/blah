struct Stacklang::ThreeAddressCode::Translator
  def translate_return(return_expression : AST::Return)
    retval = return_expression.value.try do |expression|
      target = translate_expression(expression)
      unless target
        @events.error(title: "Type error", line: expression.token.line, column: expression.token.character) do |io|
          io << "Cannot return an expression with no value"
        end
        return
      end
      target
    end

    if retval
      address, typeinfo = retval
      if typeinfo != @function.return_type
        @events.error(title: "Type error", line: return_expression.token.line, column: return_expression.token.character) do |io|
          if @function.return_type
            io << "Cannot return expression of type #{@events.emphasis(typeinfo.to_s)} from a function of type #{@events.emphasis(@function.return_type.to_s)}"
          else
            io << "Cannot return expression of type #{@events.emphasis(typeinfo.to_s)} from a function with no return type"
          end
        end
        return
      end
      @tacs << Move.new address, @return_value.not_nil!, return_expression
    elsif @function.return_type
      @events.error(title: "Type error", line: return_expression.token.line, column: return_expression.token.character) do |io|
        io << "Cannot return from a function of type #{@events.emphasis(@function.return_type.to_s)} without a return value"
      end
      return
    end

    @tacs << Return.new @return_address, return_expression
  end
end
