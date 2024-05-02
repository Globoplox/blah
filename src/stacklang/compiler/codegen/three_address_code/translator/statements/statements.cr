require "./expressions"

struct Stacklang::ThreeAddressCode::Translator
  def translate_statement(statement : AST::Statement)
    case statement
    in AST::Variable
    in AST::If
    in AST::While
    in AST::Return
    in AST::Expression then translate_expression statement
    in AST::Statement
      raise "Unexpected AST Statement node type: #{statement.class.name}"
    end
  end
end
