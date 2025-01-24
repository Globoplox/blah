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
        else raise Exception.new "Unsupported unary operator '#{expression.name}'", expression, @function
        end      
      in AST::Binary
        case expression.name
        when "+" then translate_add expression
        when "=" then translate_assignment expression
        else raise Exception.new "Unsupported binary operator '#{expression.name}'", expression, @function
        end      
      in AST::Operator
        raise "Unexpected AST Operator node type: #{expression.class.name}"
      end
    in AST::Expression
      raise "Unexpected AST Expression node type: #{expression.class.name}"
    end
  end
end
