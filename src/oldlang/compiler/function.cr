class Stacklang::Function
  include RiSC16
  alias Kind = Object::Section::Reference::Kind

  class Variable
    property initialized
    @offset : Int32
    @name : String
    @constraint : Type
    @initialization : AST::Expression?
    @restricted : Bool

    getter name
    getter constraint
    getter offset
    getter initialization
    # If the variable is currently held in a register. Work only on restricted variable (temporary var are restricted).
    getter restricted
    getter ast

    def initialize(@ast : AST?, @name, @offset, @constraint, @initialization, @restricted = false)
      @initialized = @initialization.nil?
    end
  end

  # Represent all the metadata necessary to call the function.
  # Contrary to all other stack relative offset in this file,
  # offsets here a relative to the top of caller stack frame.
  class Prototype
    class Parameter
      @offset : Int32
      @name : String
      @constraint : Type
      getter name
      getter offset
      getter constraint

      def initialize(@name, @constraint, @offset)
      end
    end

    @parameters = [] of Parameter
    @return_type : Type?
    @return_value_offset : Int32?
    @symbol : String
    getter parameters
    getter return_type
    getter return_value_offset
    getter symbol

    def initialize(@symbol, @parameters, @return_type, @return_value_offset)
    end
  end

  # The ast of the function.
  @ast : AST::Function

  # The exported symbol holding the address of the function
  @symbol : String

  # The unit containing the functions, for fetching prototypes and types.
  @unit : Unit

  # The prototype of the function, for use by other functions.
  @prototype : Prototype

  # If this function delcaration is a prototype for an external function
  @extern : Bool

  # All the variables declared in the function, including parameters.
  @variables : Hash(String, Variable)

  # The return type of the function if any.
  @return_type : Type?

  # The size of the frame of the function, without accounting potential temporary variables on top of stack.
  @frame_size : UInt16 = 0u16

  # The offset to the stack where the return value should be written when returning.
  @return_value_offset : UInt16? = nil

  # The section that will store the compiled instructions.
  @section : RiSC16::Object::Section

  # The compiled instructions.
  @text = [] of UInt16

  # A stack of temporary variables, to cache temporary values stored in register while doing other computation.
  @temporaries = [] of Variable

  # Used to generate local uniq symbols.
  @local_uniq = 0

  def name
    @ast.name.name
  end

  getter ast

  # Allow to share the prototype of the function to external symbols.
  getter prototype

  # Allow to skip compilation of prototypes only
  getter extern

  getter unit

  # Compute the prototype of the function.
  # Example of a stack frame for a simple function: `fun foobar(param1, param2):_ { var a; }`
  #
  #  +----------------------+ <- Stack Pointer (R7) value when the function function perform a call.
  #  | a          |
  #  +----------------------+
  #  | param1         | (If any)
  #  +----------------------+
  #  | param2         |
  #  +----------------------+ <- Used internaly to store return address
  #  | reserved (maybe)   | (Not always, if function is simple enough return address stays in a register through whole func
  #  +----------------------+
  #  | return value (if any)| (Only if the functio nreturn something)
  #  +----------------------+ <- Stack Pointer (R7)
  #

  # Stack frame size might be zero for very simple functions.
  # The function code decide itself if it shift the stack pointer at start, before calling, or not at all ?
  # Actually that could be kind of automatically optimized by some kind of dac
  def initialize(@ast, @unit)
    @return_type = ast.return_type.try { |r| @unit.typeinfo r }
    @extern = @ast.extern
    @symbol = "__function_#{@ast.name.name}"

    local_variables = @ast.body.compact_map(&.as? AST::Variable).map do |variable|
      typeinfo = @unit.typeinfo variable.constraint
      Variable.new(variable, variable.name.name, @frame_size.to_i32, typeinfo, variable.initialization, restricted: variable.restricted).tap do
        @frame_size += typeinfo.size
      end
    end

    parameters = @ast.parameters.map do |parameter|
      typeinfo = @unit.typeinfo parameter.constraint
      Variable.new(parameter, parameter.name.name, @frame_size.to_i32, typeinfo, nil, restricted: false).tap do
        @frame_size += typeinfo.size
      end
    end

    @variables = (parameters + local_variables).group_by do |variable|
      variable.name
    end.transform_values do |variables|
      if variables.size > 1
        message = String.build { |io|
          io << "Name clash for variable name #{variables.first.name.colorize.bold}\n"
          io << "Defined at:\n"
          variables.each do |defined|
            if (ast = defined.ast) && (token = ast.token)
              io << "- line #{token.line} column #{token.character}\n"
            end
          end
        }
        raise Exception.new message, ast: variables.first.ast, function: @ast
      else
        variables.first
      end
    end

    @return_address_offset = @frame_size
    @frame_size += 1 # We always have at least enough space for the return address

    if @return_type
      @return_value_offset = @frame_size
      @frame_size += @return_type.not_nil!.size
    end

    @prototype = Prototype.new @symbol, (
      parameters.map do |parameter|
        Prototype::Parameter.new parameter.name, parameter.constraint, parameter.offset - @frame_size
      end
    ), @return_type, @return_value_offset.try &.to_i32.-(@frame_size)

    # all functions sections are weak,
    # so dce can remove unused functions when building an executable binary.
    @section = RiSC16::Object::Section.new @symbol, options: RiSC16::Object::Section::Options::Weak
    @section.definitions[@symbol] = Object::Section::Symbol.new 0, true
  end

  def compile
    RiSC16::Object::Section.new name
  end

  def error(error, node = nil)
    location = node.try do |node|
      " at line #{node.line}"
    end
    raise "#{error}. #{@unit.path} in function #{@ast.name.name}#{location}."
  end
end
