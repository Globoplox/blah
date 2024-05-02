abstract class Stacklang::Tac
  def self.translate(expression, symbols, function, tacs, index) : String
    case expression
    #
    else
      raise InternalError.new "Unexpected expression type during intermediary code generation", expression, function: function
    end
  end

  def self.translate(block : Array(AST::Statement), symbols : Hash(String, Type), functions : Hash(String, Function), temporary_index = 0, tacs = [] of Tac, function = nil) : Int32
    block.each do |statement|
      case statement
      # Each node . . .
      else
        raise InternalError.new "Unexpected statement type during intermediary code generation", statement, function: function
      end
    end
  end
end
