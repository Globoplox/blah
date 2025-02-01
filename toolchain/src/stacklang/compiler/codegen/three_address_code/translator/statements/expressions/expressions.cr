require "./*"
require "./unary/*"
require "./binary/*"

struct Stacklang::ThreeAddressCode::Translator
  def translate_expression(expression : AST::Expression) : {Address, Type}?
    case expression
    in AST::Literal    then translate_literal expression
    in AST::Sizeof     then translate_sizeof expression
    in AST::Cast       then translate_cast expression
    in AST::Identifier then translate_identifier expression
    in AST::Call       then translate_call expression
    in AST::Operator
      case expression
      in AST::Access then translate_access expression
      in AST::Unary
        case expression.name
        when "&" then translate_reference expression
        when "*" then translate_dereference expression
        when "-" then translate_integer_opposite expression
        when "~" then translate_bitwise_not expression
        when "!" then translate_conditional_as_expression(expression) { |jumps| translate_logical_not expression, jumps }
        else          
          @events.error(title: "Unsupported unary operator '#{@events.emphasis(expression.name)}'", line: expression.token.line, column: expression.token.character) {}          
        end
      in AST::Binary
        case expression.name
        when "+"  then translate_add expression
        when "-"  then translate_substract expression
        when "&"  then translate_bitwise_and expression
        when "|"  then translate_bitwise_or expression
        when "^"  then translate_bitwise_xor expression
        when "="  then translate_assignment expression
        when "+=" then translate_sugar_assignment expression, "+"
        when "-=" then translate_sugar_assignment expression, "-"
        when "&=" then translate_sugar_assignment expression, "&"
        when "|=" then translate_sugar_assignment expression, "|"
        when "^=" then translate_sugar_assignment expression, "^"
        when "==" then translate_conditional_as_expression(expression) { |jumps| translate_is_equal expression, jumps }
        when "!=" then translate_conditional_as_expression(expression) { |jumps| translate_is_not_equal expression, jumps }
        when "&&" then translate_conditional_as_expression(expression) { |jumps| translate_logical_and expression, jumps }
        when "||" then translate_conditional_as_expression(expression) { |jumps| translate_logical_or expression, jumps }
        when "<"  then translate_conditional_as_expression(expression) { |jumps| translate_inferior_to expression, jumps }
        when "<=" then translate_conditional_as_expression(expression) { |jumps| translate_inferior_equal_to expression, jumps }
        when ">"  then translate_conditional_as_expression(expression) { |jumps| translate_superior_to expression, jumps }
        when ">=" then translate_conditional_as_expression(expression) { |jumps| translate_superior_equal_to expression, jumps }
        when "<<" then translate_binary_to_call expression, "left_bitshift"
        when ">>" then translate_binary_to_call expression, "right_bitshift"
        when "*"  then translate_binary_to_call expression, "multiply"
        when "["  then translate_table_access expression
        else
          @events.error(title: "Unsupported binary operator '#{@events.emphasis(expression.name)}'", line: expression.token.line, column: expression.token.character) {}          
        end
      in AST::Operator
        @events.error(title: "Unexpected AST Operator node type '#{@events.emphasis(expression.class.name)}'", line: expression.token.line, column: expression.token.character) {}          
      end
    in AST::Expression

    @events.error(title: "Unexpected AST Expression node type '#{@events.emphasis(expression.class.name)}'", line: expression.token.line, column: expression.token.character) {}          
    end
  end
end
