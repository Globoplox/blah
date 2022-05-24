require "../../../risc16"
require "../types"
require "../unit"

# TODO: subvar for struct var to allow for register caching. Carefull of single word struct (register cache is shared).
# TODO: Language feature: function ptr, cast
# TODO: type inference for initialized local variables
# TODO: global initialisation
class Stacklang::Function
  include RiSC16
  alias Kind = Object::Section::Reference::Kind
  
  enum Registers : UInt16
    R0;R1;R2;R3;R4;R5;R6;R7

    # Return an array containg self
    # Useful when dealing with Registers | Memory unions
    def	used_registers:	Array(Registers)
      [self]
    end
  end

  # Register free to be used for temporary values and cache
  GPR = [Registers::R1, Registers::R2, Registers::R3, Registers::R4, Registers::R5, Registers::R6]

  # Per ABI
  STACK_REGISTER = Registers::R7
  # Per ABI
  RETURN_ADRESS_REGISTER = Registers::R6

  # Represent a variable on stack with a register cache.
  # Or a temporary value in a stack cache.
  # Note: variables are not implicitely zero-initialized.
  class Variable
    # If the variable is currently held in a register. Work only on volatile variable (temporary var are volatile).
    property register : Registers? = nil
    property initialized
    @offset : Int32
    @name : String
    @constraint : Type::Any
    @initialization : AST::Expression?
    @volatile : Bool
    getter name
    getter constraint
    getter offset
    getter initialization
    getter volatile
    def initialize(@name, @offset, @constraint, @initialization, @volatile = false)
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
      @constraint : Type::Any
      getter name
      getter offset
      getter constraint
      def initialize(@name, @constraint, @offset) end
    end
    @parameters = [] of Parameter
    @return_type : Type::Any?
    @return_value_offset : Int32?
    @symbol : String
    getter parameters
    getter return_type
    getter return_value_offset
    getter symbol
    def initialize(@symbol, @parameters, @return_type, @return_value_offset) end
  end

  # The ast of the function.
  @ast : AST::Function
  # The exported symbol holding the address of the function 
  @symbol : String
  # The unit containing the functions, for fetching prototypes and types.
  @unit : Unit
  # The prototype of the function, for use by other functions.
  @prototype : Prototype
  # All the variables declared in the function, including parameters. 
  @variables : Hash(String, Variable)
  # The return type of the function if any.
  @return_type : Type::Any?
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

  # Allow to share the prototype of the function to external symbols.
  getter prototype

  # Compute the prototype of the function.
  # Example of a stack frame for a simple function: `fun foobar(param1, param2):_ { var a; }`
  #
  #  +----------------------+ <- Stack Pointer (R7) value within function
  #  | a                    |
  #  +----------------------+
  #  | param1               |
  #  +----------------------+
  #  | param2               |
  #  +----------------------+ <- Used internaly to store return address
  #  | reserved (always)    |
  #  +----------------------+ 
  #  | return value         |
  #  +----------------------+ <- Stack Pointer (R7) value from caller
  #
  def initialize(@ast, @unit)
    @return_type = ast.return_type.try { |r| @unit.typeinfo r }
    @symbol = "__function_#{@ast.name.name}"

    local_variables = @ast.variables.map do |variable|
      typeinfo = @unit.typeinfo variable.constraint
      Variable.new(variable.name.name, @frame_size.to_i32, typeinfo, variable.initialization, volatile: variable.volatile).tap do
        @frame_size += typeinfo.size
      end
    end
    
    parameters = @ast.parameters.map do |parameter|
      typeinfo = @unit.typeinfo parameter.constraint
      Variable.new(parameter.name.name, @frame_size.to_i32, typeinfo, nil, volatile: false).tap do 
        @frame_size += typeinfo.size
      end
    end

    @variables = (parameters + local_variables).group_by do |variable|
      variable.name
    end.transform_values do |variables|
      raise "Name clash for variable '#{variables.first.name}' in function '#{@ast.name}' in '#{@unit.path}' L #{@ast.line}" if variables.size > 1
      variables.first
    end

    @return_address_offset = @frame_size
    @frame_size += 1 # We always have at least enough space for the return address

    if @return_type
      @return_value_offset = @frame_size
      @frame_size += @return_type.not_nil!.size
    end
    
    @prototype = Prototype.new @symbol, (parameters.map do |parameter|
      Prototype::Parameter.new parameter.name, parameter.constraint, parameter.offset - @frame_size
    end), @return_type, @return_value_offset.try &.to_i32.-(@frame_size)
    
    @section = RiSC16::Object::Section.new @symbol, options: RiSC16::Object::Section::Options::Weak # all functions sections are weak,
    # so dce can remove unused functions when building an executable binary.
    @section.definitions[@symbol] = Object::Section::Symbol.new 0, true
  end

  def error(error, node = nil)
    location = node.try do |node|
      " at line #{node.line}"
    end
    raise "#{error}. #{@unit.path} in function #{@ast.name.name}#{location}."
  end

  # Represent a memory location as an offset to an address stored in a register or a variable.
  # It can also be specified that this memory is mapped to a (temporary or volatile) variable. This allows use of cached values.
  # That memory can be used as a source or a destination.
  class Memory
     # An offset to the reference register
    property value : Int32
    # the register containing the address. Or a variable If the address is stored in a variable.
    # For exemple, if it is r0 then this is an absolute address, if it r7 it likely a variable.
    property reference_register : Registers | Variable 
    getter within_var : Variable? # Used to identify that the location correspond to a variable, that could be currently cached into a register.

    # Helper method to use when you KNOW that the register is not held in a temporary value.
    def reference_register!
      @reference_register.as Registers
    end
        
    def initialize(@reference_register, @value, @within_var) end

    # Create a memory that is an offset to the stack. Used to create memory for variable.
    def self.offset(value : Int32, var : Variable? = nil)
      new STACK_REGISTER, value, var
    end

    # Create an absolute memory location relative to any register. 
    def self.absolute(register : Registers | Variable)
      new register, 0, nil
    end

    # Return a list of registers that this memory is using
    def used_registers: Array(Registers)
      [within_var.try(&.register), reference_register.as?(Registers) || reference_register.as(Variable).register].compact
    end
  end  
end

require "./assembly"
require "./move"
require "./statements"
require "./compile"
require "./expressions"
