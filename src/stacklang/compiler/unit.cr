require "./compiler"
require "./types"
require "./codegen"

class Stacklang::Unit
  getter path

  class Global
    getter name
    getter symbol
    getter type_info
    getter initialization
    
    # for now globals are zero initialized
    def initialize(@name : String, @type_info : Type::Any, @initialization : Nil = nil)
      @symbol = "__global_#{name}"
    end
  end
  
  @requirements: Array(Unit)? = nil
  @all_included: Array(Unit)? = nil
  @structs : Hash(String, Type::Struct)? = nil
  @globals : Hash(String, Global)? = nil

  def initialize(@ast : AST::Unit, @path : Path, @compiler : Compiler)
  end

  # Get the unit of all the directly required units.
  def requirements : Array(Unit)
    @requirements ||= @ast.requirements.map do |requirement|
      @compiler.require requirement.target, from: self
    end
  end

  # Get the unit of all the directly and indirectly required units.
  def traverse(units = [] of Unit) : Array(Unit)
    @all_included ||= begin
      units if self.in? units
      units << self
      requirements.each &.traverse
      units
    end
  end

  # Get all the structs that accessible to this unit.
  # They are solved during this process.
  def structs : Hash(String, Type::Struct)
    @structs ||= begin
      required_structs = traverse.flat_map(&.structs.values)
      self_structs = @ast.types.map do |ast|
        Type::Struct.new ast
      end
      all_structs = (self_structs + required_structs).group_by do |structure|
        structure.name
      end.transform_values do |structs|
	raise "Name clash for struct '#{structs.first.name}'" if structs.size >	1
        structs.first
      end
      self_structs.each &.solve all_structs
      all_structs
    end
  end

  def globals : Hash(String, Global)
    @globals = begin
      required_globals = traverse.flat_map(&.globals.values)
      self_globals = @ast.globals.map do |variable|
        raise "Initialization of global variable is not implemented" if variable.initialization
        Global.new variable.name, Type::Any.solve_constraint variable.constraint, structs
      end
      (self_gloabls + required_globals).group_by do |global|
	global.name
      end.transform_values do |globals|
        raise "Name clash for global '#{globals.first.name}'" if globals.size > 1
        globals.first
      end
    end
  end

  def compile
    # create symbols and well size nop for globals
    #HOWto: write the assembly code as strings, to be parsed ? Thats like, so suboptimal
    # but it is also quicker to write AND will make debug much easier
  end
  
end
