struct Stacklang::ThreeAddressCode::Translator
  def translate_return(expression : AST::Return)
    retval = expression.value.try do |expression|
      target = translate_expression(expression)
      unless target
        raise Exception.new "Cannot cast expression with no value or type", expression, @function
      end
      target
    end

    if retval
      address, typeinfo = retval
      if typeinfo != @function.return_type
        raise Exception.new "cannot return expression of type #{typeinfo} from a function of type #{@function.return_type || "None"}", expression, @function
      end
      @tacs << Move.new address, @return_value.not_nil!, expression
    elsif @function.return_type
      raise Exception.new "cannot return from a function of type #{@function.return_type} without a return value", expression, @function
    end

    @tacs << Return.new @return_address, expression
  end
end
