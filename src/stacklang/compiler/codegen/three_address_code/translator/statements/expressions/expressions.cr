require "./*"

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
      in AST::Binary
      in AST::Operator
        raise "Unexpected AST Operator node type: #{expression.class.name}"
      end
    in AST::Expression
      raise "Unexpected AST Expression node type: #{expression.class.name}"
    end
  end
end
