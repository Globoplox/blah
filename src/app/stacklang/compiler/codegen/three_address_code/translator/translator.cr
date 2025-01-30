# Translate AST to three address code.
# This does handle type checks.
struct Stacklang::ThreeAddressCode::Translator
  @tacs = [] of Code
  @anonymous = 0
  @function : Stacklang::Function
  @scope : Scope
  @return_address : Local
  @return_value : Local?
  @globals : Hash(String, {Global, Type})

  # Don't ask
  @next_uid = NextUID.new

  class NextUID
    @local_uid = 0

    def next_uid
      id = @local_uid
      @local_uid += 1
      id
    end
  end

  def next_uid
    @next_uid.next_uid
  end

  # Scope of local variables.
  # This handles nested scopes.
  # Each local variable is given an index in order of appearance from the root scope.
  class Scope
    @previous : Scope?
    @entries = {} of String => {Local, Type}

    # Build a scope from a body of statements.
    def initialize(prev : Scope, statements : Array(AST::Statement), function : Stacklang::Function, uid : NextUID)
      @previous = prev
      statements.each do |statement|
        next unless statement.is_a? AST::Variable
        raise Exception.new "Redeclaration of variable #{statement.name}", statement, function if search(statement.name.name) != nil
        typeinfo = function.unit.typeinfo(statement.constraint)
        @entries[statement.name.name] = {
          Local.new(uid.next_uid, 0, typeinfo.size.to_i, statement, restricted: statement.restricted),
          typeinfo,
        }
      end
    end

    # Build a scope from the root scope of a function including it's parameters only.
    def initialize(function : Stacklang::Function, uid : NextUID)
      @previous = nil
      function.parameters.each do |parameter|
        raise Exception.new "Parameter name conflict '#{parameter.name}'", parameter.ast, function if @entries[parameter.name]? != nil
        # Shadowing is allowed
        @entries[parameter.name] = {Local.new(uid.next_uid, 0, parameter.constraint.size.to_i, parameter.ast, abi_expected_stack_offset: parameter.offset), parameter.constraint}
      end
    end

    def search(name : String) : {Local, Type}?
      @entries[name]? || @previous.try(&.search name)
    end

    def previous : Scope
      @previous
    end

    def offset : Int32q
      @offset
    end
  end

  def anonymous(size : Int32)
    Anonymous.new(@anonymous += 1, size)
  end

  def initialize(@function)
    @globals = @function.unit.globals.map do |(name, global)|
      {name, {Global.new(global.symbol, global.typeinfo.size.to_i, global.ast), global.typeinfo}}
    end.to_h

    # Local offset to store the return value if any (at ABI enforced location)
    @return_value = @function.return_type.try do |typeinfo|
      Local.new(next_uid, 0, typeinfo.size.to_i, @function.ast, abi_expected_stack_offset: @function.return_value_offset.not_nil!, restricted: true)
    end
    # Top Level var and parameters (parameters with ABI enforced location)
    @scope = Scope.new(Scope.new(@function, @next_uid), @function.ast.body, @function, @next_uid)
    # local offset used to store the return address
    @return_address = Local.new(next_uid, 0, 1, @function.ast)
  end
end

require "./statements"

struct Stacklang::ThreeAddressCode::Translator
  def translate : Array(Code)
    @tacs << Start.new @return_address, @function.ast
    @function.ast.body.each do |statement|
      translate_statement statement
    end
    @tacs
  end
end
