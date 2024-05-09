require "./expressions"

struct Stacklang::ThreeAddressCode::Translator
  def translate_statement(statement : AST::Statement)
    case statement
    in AST::Variable then statement.initialization.try { |expression| translate_expression expression } 
    in AST::If
    in AST::While
    in AST::Return
    in AST::Expression then translate_expression statement
    in AST::Statement
      raise "Unexpected AST Statement node type: #{statement.class.name}"
    end
  end
end
