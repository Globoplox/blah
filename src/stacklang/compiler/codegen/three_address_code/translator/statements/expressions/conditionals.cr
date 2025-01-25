struct Stacklang::ThreeAddressCode::Translator
  # Conditonals and comparisons expressions return a result of 0 if false or any other value if true
  # However most of the time the result value itself is not used to compute but to jump.
  # Operations that requires boolean need to perform jumps to assign the right value 
  # but this is often redondant with other previously planned umps.
  # This struct when instead of producing a value, the conditional or comparisons operation simply jump to the given label
  struct ConditionalJumps
    property if_true : String
    property if_false : String

    def initialize(@if_true, @if_false)
    end
  end

  # Take an expression and jump accordingly to it's truthiness
  def translate_conditional(expression : AST::Expression, jumps : ConditionalJumps)
    case expression
    when AST::Operator
      case expression
      when AST::Unary
        case expression.name
        when "!" then return translate_logical_not expression, jumps
        end      
      when AST::Binary
        case expression.name
        when "==" then return translate_is_equal expression, jumps
        when "!=" then return translate_is_not_equal expression, jumps
        when "<" then return
        when ">" then return
        when "<=" then return
        when ">=" then return
        when "&&" then return translate_logical_and expression, jumps
        when "||" then return translate_logical_or expression, jumps
        end
      end
    end

    # If we have not return, this mean the expression does not usually deal with bool and we must check it's value and jump
    condition = translate_expression expression
    if condition.nil?
      raise Exception.new "Expression has no type", expression, @function
    end
    condition_address, condition_typeinfo = condition

    # If expression is false, jump to if_false
    @tacs << JumpEq.new(jumps.if_false, {condition_address, Immediate.new 0, expression}, expression)
    # jump to if_true otherwise
    @tacs << JumpEq.new(jumps.if_true, nil, expression)
  end 

  # TODO: the opposite function, that produce an actual value from the conditonnal operators that usually just jump
end