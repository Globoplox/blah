require "./compiler"
require "./types"
require "./function"
require "../../assembler/object"
require "../../assembler/linker"

class Stacklang::Unit
  getter path

  class Global
    getter name : String
    getter symbol
    getter type_info : Type::Any
    getter initialization
    getter extern
    getter ast
    @name : String
    @type_info : Type::Any
    @extern : Bool
    @initialization : Stacklang::AST::Expression?
    @ast : AST::Variable?

    def initialize(ast : AST::Variable, @type_info)
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
        if functions.size > 1
          message = String.build { |io|
            io << "Name clash for function name #{functions.first.name.colorize.bold}\n"
            io << "Defined in:\n"
            functions.each do |defined|
              if token = defined.ast.token
                source = token.source
                if source
                  rel = Path[source].relative_to(Dir.current).to_s
                  source = rel if rel.size < source.size
                end			
                io << "- #{source} line #{token.line} column #{token.character}\n"
              end
            end
          }
          raise Exception.new message, ast: functions.first.ast
        end
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
        if structs.size > 1
          message = String.build { |io|
            io << "Name clash for struct type #{structs.first.name.colorize.bold}\n"
            io << "Defined in:\n"
            structs.each do |defined|
              if token = defined.ast.token
                source = token.source
                if source
                  rel = Path[source].relative_to(Dir.current).to_s
                  source = rel if rel.size < source.size
                end			
                io << "- #{source} line #{token.line} column #{token.character}\n"
              end
            end
          }
          raise Exception.new message, ast: structs.first.ast
        end
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
      Global.new variable, Type::Any.solve_constraint(variable.constraint, structs)
    end
  end

  def globals : Hash(String, Global)
    @globals ||= begin
      required_globals = externs.flat_map(&.self_globals)
      linker_globals = RiSC16::Linker.symbols_from_spec(@compiler.spec).map do |(name, _)|
        Global.new symbol: name
      end
      all_globals = (self_globals + required_globals + linker_globals).group_by(&.name)
      
      all_globals.transform_values do |globals|
        if globals.size > 1
          message = String.build { |io|
            io << "Name clash for global name #{globals.first.name.colorize.bold}\n"
            io << "Defined in:\n"
            globals.each do |defined|
              if (ast = defined.ast) && (token = ast.token)
                source = token.source
                if source
                  rel = Path[source].relative_to(Dir.current).to_s
                  source = rel if rel.size < source.size
                end			
                io << "- #{source} line #{token.line} column #{token.character}\n"
              else 
                io << "- Compiler generated global from specifications raw symbol: #{defined.symbol}"
              end
            end
          }
          raise Exception.new message, ast: globals.first.ast
        else
          globals.first
        end
      end
    end
  end

  def compile
    structs
    globals
    functions
    RiSC16::Object.new(path.to_s).tap do |object|
      object.sections << RiSC16::Object::Section.new("globals").tap do |section|
        code = [] of RiSC16::Word
        self_globals.each do |local|
          next if local.extern
          section.definitions[local.symbol] = RiSC16::Object::Section::Symbol.new code.size, true
          if local.initialization
            case local.type_info
            when Type::Word # There is code duplication here with function var init/typechecking
              case expression = local.initialization
              when Stacklang::AST::Literal
                code << expression.number.to_u16!
              else
                raise Exception.new "Global #{local.name.colorize.bold} of type _ initialization support literal values only.", ast: local.ast
              end
            else
              raise Exception.new "Global #{local.name.colorize.bold} of type #{local.type_info} initialization not supported", ast: local.ast
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
