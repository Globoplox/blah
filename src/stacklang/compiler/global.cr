require "./type"

class Stacklang::Global
  getter name : String
  getter symbol
  getter typeinfo : Type
  getter initialization
  getter extern
  getter ast

  @name : String
  @typeinfo : Type
  @extern : Bool
  @initialization : Stacklang::AST::Expression?
  @ast : AST::Variable?

  def initialize(ast : AST::Variable, @typeinfo)
    @ast = ast
    @name = ast.name.name
    @initialization = ast.initialization
    @extern = ast.extern
    @symbol = "__global_#{name}"
  end

  # Used to define globals for value defined by the linker, those are raw symbols
  def initialize(@symbol : String)
    @name = @symbol
    @extern = true
    @typeinfo = Type::Word.new
  end
end
