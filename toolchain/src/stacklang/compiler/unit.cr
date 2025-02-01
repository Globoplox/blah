require "./compiler"
require "./type"
require "./function"
require "./global"

# Represent a single unit / source file.
# It has a compiler backreference, that is used to solve requirements
# and grab symbol and types definition from elsewhere.
class Stacklang::Unit
  getter path

  @requirements : Array(Unit)? = nil
  @self_structs : Array(Type::Struct)? = nil
  @self_functions : Array(Function)? = nil
  @self_globals : Array(Global)? = nil
  @structs : Hash(String, Type::Struct)? = nil
  @functions : Hash(String, Function)? = nil
  @globals : Hash(String, Global)? = nil
  
  def initialize(@ast : AST::Unit, @path : String, @compiler : Compiler, @events : Toolchain::EventStream, @spec : RiSC16::Spec, @require_chain : Array(Unit) = [] of Unit)
  end

  @traversed : Array(Unit)? = nil
  # Get the unit of all the directly and indirectly required units.
  def traverse
    @traversed ||= (([] of Unit).tap do |units|
      traverse units, [] of Unit
    end.uniq)
  end

  # Get the unit of all the directly and indirectly required units.
  def traverse(units, require_chain)
    return if self.in? units
    units << self
    require_chain << self
    return @requirements if @requirements

    @requirements = requirements = [] of Unit
    
    @ast.requirements.flat_map do |requirement|
      @events.with_context "requiring #{requirement.target}", requirement.token.source, requirement.token.line, requirement.token.character do
        required = @compiler.require requirement.target, from: self, require_chain: require_chain
        requirements << required
        required.traverse units, require_chain.map(&.itself)
      end
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
          locations = functions.compact_map do |defined|
            if token = defined.ast.token
              source = token.source
              if source
                rel = Path[source].relative_to(Dir.current).to_s
                source = rel if rel.size < source.size
              end
              {source.as(String?), token.line.as(Int32?), token.character.as(Int32?)}
            end
          end

          @events.fatal!(
            title: "Name clash for function #{@events.emphasis(functions.first.name)}:",
            locations: locations
          )
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
          locations = structs.compact_map do |defined|
            if token = defined.ast.token
              source = token.source
              if source
                rel = Path[source].relative_to(Dir.current).to_s
                source = rel if rel.size < source.size
              end
              {source.as(String?), token.line.as(Int32?), token.character.as(Int32?)}
            end
          end

          @events.fatal!(
            title: "Name clash for struct #{@events.emphasis(structs.first.name)}:",
            locations: locations
          )
        end
        structs.first
      end
      self_structs.each &.solve all_structs
      all_structs
    end
  end

  def typeinfo(constraint)
    Type.solve_constraint constraint, structs
  end

  def self_globals : Array(Global)
    @self_globals ||= @ast.globals.map do |variable|
      # raise "Initialization of global variable is not implemented" if variable.initialization
      Global.new variable, Type.solve_constraint(variable.constraint, structs)
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

          locations = globals.compact_map do |defined|
            if (ast = defined.ast) && (token = ast.token)
              source = token.source
              if source
                rel = Path[source].relative_to(Dir.current).to_s
                source = rel if rel.size < source.size
              end
              {source.as(String?), token.line.as(Int32?), token.character.as(Int32?)}
            else
              {@spec.path.as(String?), nil.as(Int32?), nil.as(Int32?)}
            end
          end

          @events.fatal!(
            title: "Name clash for global #{@events.emphasis(globals.first.name)}:",
            locations: locations
          )
        end
        globals.first
      end
    end
  end
end
