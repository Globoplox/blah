require "./compiler"
require "./types"
require "./function"
require "../../assembler/object"

# We compile ONLY the thing in the current unit, the requirements are for info only (globals and functions are not compiled).
# If we need them, compile both file and link.
class Stacklang::Unit
  getter path

  class Global
    getter name
    getter symbol
    getter type_info
    getter initialization
    
    # for now globals are zero initialized
    def initialize(@name : String, @type_info : Type::Any, @initialization : Int32 = 0) #initialisation Int32 is a placeholder
      @symbol = "__global_#{name}"
    end
  end
  
  @requirements: Array(Unit)? = nil
  @self_structs : Array(Type::Struct)? = nil
  @self_functions : Array(Function)? = nil
  @self_globals : Array(Global)? = nil
  @structs : Hash(String, Type::Struct)? = nil
  @functions : Hash(String, Function)? = nil
                                   
  def initialize(@ast : AST::Unit, @path : Path, @compiler : Compiler)
  end
  
  # Get the unit of all the directly required units.
  def requirements : Array(Unit)
    @requirements ||= @ast.requirements.map do |requirement|
      @compiler.require requirement.target, from: self
    end
  end

  # Get the unit of all the directly and indirectly required units.
  def traverse
    ([] of Unit).tap do |units|
      traverse units
    end.uniq
  end
  
  # Get the unit of all the directly and indirectly required units.
  def traverse(units)
    return if self.in? units
    units << self
    requirements.each do |requirement|
        requirement.traverse units
    end
  end

  def externs
    traverse.reject(&.== self)
  end

  def self_functions
    @self_functions ||= @ast.functions.map do |ast|
      Function.new ast, self
    end
  end

  def functions
    @functions ||= begin
      (self_functions + externs.flat_map(&.self_functions)).group_by do |function|
	function.name
      end.transform_values do |functions|
        raise "Name clash for function '#{functions.first.name}'" if functions.size > 1
        functions.first
      end               
    end
  end

  def self_structs
    @self_structs ||= @ast.types.map do |ast|
      Type::Struct.new ast
    end
  end
  
  # Get all the structs that accessible to this unit.
  # They are solved during this process.
  def structs : Hash(String, Type::Struct)
    @structs ||= begin
      required_structs = externs.flat_map(&.self_structs)
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

  def typeinfo(constraint)
    Type::Any.solve_constraint constraint, structs
  end

  def self_globals : Array(Global)
    @self_globals ||= @ast.globals.map do |variable|
      raise "Initialization of global variable is not implemented" if variable.initialization
      Global.new variable.name.name, Type::Any.solve_constraint variable.constraint, structs
    end
  end

  def compile
    RiSC16::Object.new(path.to_s).tap do |object|
      object.sections << RiSC16::Object::Section.new("globals").tap do |section|
        size = self_globals.reduce(0u16) do |size, local|
          raise "Duplicate local global #{local.name} in #{path}" if section.definitions[local.symbol]?
          section.definitions[local.symbol] = RiSC16::Object::Section::Symbol.new size.to_i32, true
          size + local.type_info.size
        end
        section.text = Slice(UInt16).new size
      end
      self_functions.each do |function| 
        object.sections << function.compile
      end
    end
  end
  
end
