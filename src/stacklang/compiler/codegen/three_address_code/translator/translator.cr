# Translate AST to three address code.
# This does handle type checks.
struct Stacklang::ThreeAddressCode::Translator
  @tacs = [] of {Code, Type?}
  @anonymous = 0
  @function : Function
  @scope : Scope
  @globals : Hash(String, {Global, Type})

  # Scope of local variables.
  # This handles nested scopes.
  # Each local variable is given an index in order of appearance from the root scope.
  class Scope
    @previous : Scope?
    @entries = {} of String => {Local, Type}
    @index : Int32

    # Build a scope from a body of statements.
    def initialize(@previous, statements : Array(AST::Statement), function : Function)
      @index = @previous.try(&.index) || 0
      statements.each do |statement|
        next unless statement.is_a? AST::Variable
        raise Exception.new "Redeclaration of variable #{statement.name}", statement, function if search(statement.name.name) != nil
        @entries[statement.name.name] = {Local.new(@index, 0, statement), function.unit.typeinfo(statement.constraint)}
        @index += 1
      end
    end

    # Build a scope from the root scope of a function including it's parameters only.
    def initialize(function : Function)
      @previous = nil
      @index = 0
      function.parameters.each do |parameter| 
        raise Exception.new "Parameter name conflict '#{parameter.name}'", parameter.ast, function if @entries[parameter.name]? != nil
        @entries[parameter.name] = {Local.new(@index, 0, parameter.ast), parameter.constraint}
        @index += 1
      end
    end

    def search(name : String) : {Local, Type}?
      @entries[name]? || @previous.try(&.search name)
    end

    def previous : Scope
      @previous
    end

    def index : Int32
      @index
    end
  end

  def anonymous
    Anonymous.new(@anonymous += 1)
  end

  def initialize(@function)
    @globals = @function.unit.globals.map do |(name, global)|
      {name, {Global.new(name, 0, global.ast), global.typeinfo}}
    end.to_h
    @scope = Scope.new(Scope.new(@function), @function.ast.body, @function)
  end
end

require "./statements"

struct Stacklang::ThreeAddressCode::Translator
  def translate : Array({Code, Type?})
    @function.ast.body.each do |statement|
      translate_statement statement
    end
    @tacs
  end
end
