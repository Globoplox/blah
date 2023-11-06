class Stacklang::Function
  # Compile the value of any operation and move it's value if necessary.
  def compile_operator(operator : AST::Operator, into : Registers | Memory | Nil) : Type::Any
    case operator
    when AST::Unary  then compile_any_unary operator, into: into
    when AST::Binary then compile_assignment_or_binary operator, into: into
    when AST::Access then compile_access operator, into: into
    else                  error "Unsuported operator", node: operator
    end
  end

  # Compile the value of any expression and move it's value if necessary.
  def compile_expression(expression : AST::Expression, into : Registers | Memory | Nil) : Type::Any
    case expression
    when AST::Literal    then compile_literal expression, into: into
    when AST::Sizeof     then compile_sizeof expression, into: into
    when AST::Call       then compile_call expression, into: into
    when AST::Identifier then compile_identifier expression, into: into
    when AST::Operator   then compile_operator expression, into: into
    when AST::Cast
      compile_expression expression.target, into: into
      @unit.typeinfo expression.constraint
    else error "Unsupported expression", node: expression
    end
  end
end

require "./leaf"
require "./call"
require "./assignment"
require "./unary"
require "./binary"
