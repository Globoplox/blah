require "./*"
require "./expressions"

struct Stacklang::ThreeAddressCode::Translator
  def translate_statement(statement : AST::Statement)
    case statement
    in AST::Variable   then statement.initialization.try { |expression| translate_expression expression }
    in AST::If         then translate_if statement
    in AST::While      then translate_while statement
    in AST::Return     then translate_return statement
    in AST::Expression then translate_expression statement
    in AST::Statement
      raise "Unexpected AST Statement node type: #{statement.class.name}"
    end
  end
end
