require "./compiler"
require "./types"
require "./function"
require "../../assembler/object"
require "../../assembler/linker"

class Stacklang::Unit
  getter path

  class Global
    getter name
    getter symbol
    getter type_info
    getter initialization
    getter extern
    @initialization : Stacklang::AST::Expression?

    # for now globals are zero initialized
    def initialize(@name : String, @type_info : Type::Any, @initialization, @extern)
      @symbol = "__global_#{name}"
    end

    # Used to define globals for value defined by the linker, those are raw symbols
    def initialize(@symbol : String)
      @name = @symbol
      @extern = true
      @type_info = Type::Word.new
    end
  end

  @requirements : Array(Unit)? = nil
  @self_structs : Array(Type::Struct)? = nil
  @self_functions : Array(Function)? = nil
  @self_globals : Array(Global)? = nil
  @structs : Hash(String, Type::Struct)? = nil
  @functions : Hash(String, Function)? = nil
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
        raise "Name clash for struct '#{structs.first.name}'" if structs.size > 1
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
      # raise "Initialization of global variable is not implemented" if variable.initialization
      Global.new variable.name.name, Type::Any.solve_constraint(variable.constraint, structs), initialization: variable.initialization, extern: variable.extern
    end
  end

  def globals : Hash(String, Global)
    @globals ||= begin
      required_globals = externs.flat_map(&.self_globals)
      all_globals = (self_globals + required_globals).group_by do |global|
        global.name
      end.transform_values do |globals|
        raise "Name clash for global '#{globals.first.name}'" if globals.size > 1
        globals.first
      end
    end.tap do |globals|
      RiSC16::Linker.symbols_from_spec(@compiler.spec).each do |(name, _)|
        globals.not_nil![name] = Global.new symbol: name
      end
    end
  end

  def compile
    RiSC16::Object.new(path.to_s).tap do |object|
      object.sections << RiSC16::Object::Section.new("globals").tap do |section|
        code = [] of RiSC16::Word
        self_globals.each do |local|
          raise "Duplicate local global #{local.name} in #{path}" if section.definitions[local.symbol]?
          next if local.extern
          section.definitions[local.symbol] = RiSC16::Object::Section::Symbol.new code.size, true
          if local.initialization
            # we can do _ = word, *_ = &identifier
            case local.type_info
            when Type::Word # There is code duplication here with function var init/typechecking
              local.initialization.as?(Stacklang::AST::Literal).try &.tap do |literal|
                code << literal.number.to_u16! # TODO: better error message, resuse function logic ?
              end || raise "Type does not match affected value initializing global #{local.name} of type #{local.type_info} with value #{local.initialization}"
              # when Type::Pointer # do later, allows to initialize with dereferenced identifier. Typecheck. Would work only on var since
              # there are no func ptr type yet
              # when Type::Table # do later, need recursive stuff, annoying
              # when Type::Struct # do later, need recursive stuff, annoying
            else "Intializing global #{local.name} of type #{local.type_info} is not supported yet"
            end
          else
            local.type_info.size.times do
              code << 0u16
            end
          end
        end
        section.text = Slice.new code.size do |i|
          code[i]
        end # TODO ugly, fix
      end
      self_functions.each do |function|
        object.sections << function.compile unless function.extern
      end
    end
  end
end
