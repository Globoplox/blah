require "../../risc16"
require "./types"
require "./unit"

# TODO: all operator, calls (carefull of tmp var, and that the return value is moved by the amount of tmp var).
# TODO: handle copy with index in a temporary register with a beq loop ?
# TODO: when doing a movi and the value is a flat 0, we could do a sw r0, ,0 instead of a movi
# TODO: a dedicated function for generating movi
# TODO: Function to generate error
# TODO: subvar for struct var to allow for register caching. Carefull of single word struct (register cache is shared).
# TODO: Language feature: function ptr, cast
class Stacklang::Function
  include RiSC16
  alias Kind = Object::Section::Reference::Kind
  
  enum Registers : UInt16
    R0;R1;R2;R3;R4;R5;R6;R7
  end

  # Register free to be used for temporary values and cache
  GPR = [Registers::R1, Registers::R2, Registers::R3, Registers::R4, Registers::R5, Registers::R6]

  # Per ABI
  STACK_REGISTER = Registers::R7
  # Per ABI
  RETURN_ADRESS_REGISTER = Registers::R6

  # Represent a variable on stack with a register cache
  # Or a temporary value in a stack cache.
  # Note: variables are not implicitely zero-initialized.
  class Variable
    property register : Registers? = nil
    property initialized
    @offset : Int32
    @name : String
    @constraint : Type::Any
    @initialization : AST::Expression?
    getter name
    getter constraint
    getter offset
    getter initialization
    def initialize(@name, @offset, @constraint, @initialization)
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
    @parameters = {} of String => Parameter
    @return_type : Type::Any?
    @return_value_offset : Int32?    
    getter parameters
    getter return_type
    getter return_value_offset
    def initialize(@parameters, @return_type, @return_value_offset) end
  end

  # The ast of the function.
  @ast : AST::Function
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

  # Run a computation step while ensuring a register value is kept or cached in stack.
  # (Unless an mistake in the compiler cause use of register it shouldn't).
  def with_temporary(register : Registers, constraint : Type::Any)
    tmp = Variable.new "__temporary_var_#{@temporaries.size}", -(@temporaries.size + 1), constraint, nil
    tmp.register = register
    @temporaries.push tmp
    yield tmp
    @temporaries.pop
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
  #  +----------------------+ <- Used internaly to store return value
  #  | reserved (always)    |
  #  +----------------------+ 
  #  | return value         |
  #  +----------------------+ <- Stack Pointer (R7) value from caller
  #
  def initialize(@ast, @unit)
    @return_type = ast.return_type.try { |r| @unit.typeinfo r }
    
    local_variables = @ast.variables.map do |variable|
      typeinfo = @unit.typeinfo variable.constraint
      Variable.new(variable.name.name, @frame_size.to_i32, typeinfo, variable.initialization).tap do
        @frame_size += typeinfo.size
      end
    end
    
    parameters = @ast.parameters.map do |parameter|
      typeinfo = @unit.typeinfo parameter.constraint
      Variable.new(parameter.name.name, @frame_size.to_i32, typeinfo, nil).tap do 
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
    
    @prototype = Prototype.new (parameters.to_h do |parameter|
      {parameter.name, Prototype::Parameter.new parameter.name, parameter.constraint, parameter.offset - @frame_size}
    end), @return_type, @return_value_offset.try &.to_i32.-(@frame_size)
    
    @section = RiSC16::Object::Section.new "__function_#{@ast.name.name}"
    @section.definitions["__function_#{@ast.name.name}"] = Object::Section::Symbol.new 0, true
  end

  # Helper function for assembling immediate value.
  # It provide a value for the immediate, or store the reference for linking if the value is a symbol.
  def assemble_immediate(immediate, kind, symbol_offset = 0)
    if immediate.is_a? String
      references = @section.references[immediate] ||= [] of Object::Section::Reference
      references << Object::Section::Reference.new @text.size.to_u16, symbol_offset, kind
      0u16
    else
      immediate += symbol_offset
      bits = case kind
        when .imm?, .beq? then 7
        else 16
      end
      value = (immediate < 0 ? (2 ** bits) + immediate.bits(0...(bits - 1)) : immediate).to_u16
      value = value >> 6 if kind.lui?
      value = value & 0x3fu16 if kind.lli?
      value
    end
  end

  # Ensure a variable value is written to ram and not in a cache so the register can be used for something else.
  def store(variable)
    variable.register.try do |register|
      lvalue = compile_variable_lvalue variable
      move register, variable.constraint, lvalue, force_to_memory: true
    end
  end

  # Grab a register not excluded, free to use.
  # If the grabbed register is used as a cache for a variable, or is holding a temporary value,
  # the var is written to the stack so value is not lost.
  def grab_register(excludes = [] of Registers)
    free = (GPR - excludes - @temporaries.compact_map(&.register) - @variables.values.compact_map(&.register).uniq)[0]?
    return free if free
    selected = (GPR - excludes).shuffle.first
    (@variables.values + @temporaries).each do |variable|
      if variable.register == selected
        store variable
        variable.register = nil
      end
    end
    selected
  end

  # Represent a memory location as an offset to an address stored in a register or a variable.
  # It can also be specified that this memory is mapped to a variable. This allows use of cached values.
  # That memory can be used as a source or a destination.
  #
  # TODO: the value is never actually a symbol. This case should be removed.
  # This will also allow to remove #assembler_immediate symbol_offset parameter, and the symbol_offset property.
  class Memory
    property symbol_offset : Int32 # offset to symbol_offset but work also when value is a string
    getter value : Int32 | String # the offset to reference_register
    property reference_register : Registers | Variable # the register containing the address. Or a variable If the address is stored in a variable
    getter within_var : Variable? # used to identify that the ram correspond to a var, that could be currently cached into a register

    # Helper method to use when you KNOW that the register is not held in a temporary value.
    def reference_register!
      @reference_register.as Registers
    end
        
    def initialize(@reference_register, @value, @symbol_offset, @within_var) end

    # Create a memory that is an offset to the stack. Used to create memory for variable.
    def self.offset(value : Int32, var : Variable? = nil)
      new STACK_REGISTER, value, 0, var
    end

    # Create an absolute memory location relative to any register. 
    def self.absolute(register : Registers, value : Int32 | String = 0, symbol_offset : Int32 = 0)
      new register, value, symbol_offset, nil
    end

    def cache_to_s
      if var = @within_var
        "AKA var #{var.name} whose value is cached in #{var.register}"
      end
    end

    def rel_to_s
      case ref = @reference_register
      when Registers then "#{ref}"
      when Variable then "address found in var #{ref.name} (cached in #{ref.register})"
      end
    end

    def to_s(io)
      io << "Memory (#{cache_to_s}) at address relative to #{rel_to_s}"
    end
  end

  # This is the big one.
  # Move a bunch of memory from a source to a destination.
  # It handle a wide range of case:
  # - If the source value is in a register
  # - If the source value is found at an address represented by an offset relative to an address in a register 
  # - If the source value is a variable that is cached in a register
  # - If the source value is found at an address represented by an offset relative to a address in a variable
  # - If the destination is a register
  # - If the destination address is represented by an offset relative to an address in a register
  # - If the destination address is represented by an offset relative to an address in a variable
  # - If the destination is a variable that is or could be cached in a register
  # All variable cache optimisation where a variable memory destination is not really written to
  # thanks to caching within register can be disabled by setting *force_to_memory* to true.
  # That should be usefull only when storing a var because it's cache register is needed for something else.
  def move(memory : Memory | Registers, constraint : Type::Any, into : Memory | Registers, force_to_memory = false)
    pp "MOVE #{memory} into #{into}"
    # If the source is a memory location holding a variable that is already cached into a register, then use this register directly.
    memory = memory.within_var.try(&.register) || memory if memory.is_a? Memory

    # If the source is a memory location relative to an address stored into a variable, we need to get that address into a register.
    memory.reference_register.as?(Variable).try do |address_variable|
      # If the var containing that address is cached in a register, just use the cache.
      if (address_register = address_variable.register)
        memory.reference_register = address_register
      else
        # Else we need to dereference it? For this we grab a register, ensuring we are not going to grab a register necessary for next steps. 
        address_register = grab_register(excludes: [
            into.as?(Registers) ||
            into.as?(Memory).not_nil!.within_var.try(&.register) ||
            into.as?(Memory).not_nil!.reference_register ||
            into.as?(Memory).not_nil!.reference_register.as?(Variable).try(&.register)].compact)
        @text << Instruction.new(ISA::Lw, address_register.value, STACK_REGISTER.value, immediate: assemble_immediate address_variable.offset, Kind::Imm).encode
        memory.reference_register = address_variable.register = address_register
      end
    end if memory.is_a? Memory

    # If the destination is a memory location relative to an address stored into a variable, we need to get that address into a register.
    # In this case, 
    into.reference_register.as?(Variable).try do |address_variable|
      # If the var containing that address is cached in a register, just use the cache.
      if (address_register = address_variable.register)
        into.reference_register = address_register
      else
        # Else we need to dereference it? For this we grab a register, ensuring we are not going to grab a register necessary for next steps.
        address_register = grab_register excludes: [memory.as?(Registers) || memory.as?(Memory).not_nil!.reference_register].compact
        @text << Instruction.new(ISA::Lw, address_register.value, STACK_REGISTER.value, immediate: assemble_immediate address_variable.offset, Kind::Imm).encode
        into.reference_register = address_variable.register = address_register
      end
    end if into.is_a? Memory
    
    case {memory, into}
    when {Registers, Registers}
      @text << Instruction.new(ISA::Add, into.value, memory.value).encode unless into == memory

    when {Registers, Memory}
      pp "Reg => Mem"
      if force_to_memory == false && (var = into.within_var) && var.constraint.size == 1
        pp "Into is word-size var, optimizing"
        var.register = memory
      else
        pp "Store #{memory} to #{into} + #{into.value} + #{into.symbol_offset}"
        @text << Instruction.new(ISA::Sw, memory.value, into.reference_register!.value, immediate: assemble_immediate into.value, Kind::Imm, into.symbol_offset).encode
      end

    when {Memory, Registers}
      raise "Illegal move of multiple word into register" if constraint.size > 1
      @text << Instruction.new(ISA::Lw, into.value, memory.reference_register!.value, immediate: assemble_immediate memory.value, Kind::Imm, memory.symbol_offset).encode

    when {Memory, Memory}
      if force_to_memory == false &&  (var = into.within_var) && var.constraint.size == 1
        target_register = var.register || grab_register excludes: [memory.reference_register!]
        @text << Instruction.new(
          ISA::Lw, target_register.value, memory.reference_register!.value, immediate: assemble_immediate memory.value, Kind::Imm, memory.symbol_offset
        ).encode
        var.register = target_register

      else
        # TODO: if force_to_memory is false and we find out both location are the same, no need to compile anything.
        tmp_register = grab_register excludes: [into.reference_register!, memory.reference_register!]
        (0...(constraint.size)).each do |index|
          @text << Instruction.new(
            ISA::Lw, tmp_register.value, memory.reference_register!.value, immediate: assemble_immediate memory.value, Kind::Imm, memory.symbol_offset + index
          ).encode
          @text << Instruction.new(
            ISA::Sw, tmp_register.value, into.reference_register!.value, immediate: assemble_immediate into.value, Kind::Imm, into.symbol_offset + index
          ).encode
        end
        
      end
    end
  end

  # Generate code necessary to move a single-word literal value in any location.
  def compile_literal(literal : AST::Literal, into : Registers | Memory | Nil): Type::Any?
    # An expression composed of just a literal is useless (it can't have a side effect).
    pp "Literal (#{literal.number}) move into #{into}"
    return nil if into.nil?
    case into
    when Registers
      @text << Instruction.new(ISA::Lui, into.value, immediate: assemble_immediate literal.number, Kind::Lui).encode
      @text << Instruction.new(ISA::Addi, into.value, into.value, immediate: assemble_immediate literal.number, Kind::Lli).encode
    when Memory
      tmp_register = into.within_var.try(&.register) || grab_register excludes: [into.reference_register]
      @text << Instruction.new(ISA::Lui, tmp_register.value, immediate: assemble_immediate literal.number, Kind::Lui).encode
      @text << Instruction.new(ISA::Addi, tmp_register.value, tmp_register.value, immediate: assemble_immediate literal.number, Kind::Lli).encode
      # The move will compute to no-op automatically if this ends up copying a register to itself.
      move tmp_register, Type::Word.new, into
    end
    Type::Word.new
  end

  # Generate code necessary to move a global variable value in any location.
  def compile_global(global : Unit::Global, into : Registers | Memory | Nil): Type::Any?
    # An expression composed of just a global is useless (it can't have a side effect).
    return nil if into.nil?
    source = compile_global_lvalue global
    move source, global.type_info, into
    global.type_info
  end

  # Generate code necessary to move a variable value in any location.
  def compile_variable(variable : Variable, into : Registers | Memory | Nil): Type::Any?
    # An expression composed of just a variable is useless (it can't have a side effect).
    return nil if into.nil?
    raise "Cannot use variable #{variable.name} before it is initalized" unless variable.initialized
    source = compile_variable_lvalue variable
    move source, variable.constraint, into
    variable.constraint
  end

  # Generate code necessary to move any value represened by an identifier in any location.
  def compile_identifier(identifier : AST::Identifier, into : Registers | Memory | Nil): Type::Any?
    # An expression composed of just an identifier is useless (it can't have a side effect).
    return nil if into.nil?
    variable = @variables[identifier.name]?
    if variable
      compile_variable variable, into: into
    else
      global = @unit.globals[identifier.name]?
      global || raise "Unknown identifier #{identifier.name} in #{@unit.path} at line #{identifier.line}" 
      compile_global global, into: into
    end
  end

  # def compile_call(call : AST::Call, into : Registers | Offset | Nil): Type::Any?
  #   # find the func prototype
  #   function = @unit.functions[identifier.name.name]? || "Unknown functions #{identifier.name} in #{@unit.path} at line #{call.line}"
  #   # check that we are not trying to put a multiple word return value into a register
  #   # for each paramter: copy into futur stack
  #   # call
  #   # depending on the into, copy the return value
  # end

  # Get the memory location and type represented an access.
  # This work by obtaining a memory location for its subvalue and adding the accessed field offset.
  def compile_access_lvalue(access : AST::Access) : {Memory, Type::Any}?
    lvalue_result = compile_lvalue access.operand
    if lvalue_result
      lvalue, constraint = lvalue_result
      if constraint.is_a? Type::Struct
        field = constraint.fields.find &.name.== access.field.name
        field || raise "No such field #{access.field.name} for struct #{constraint.to_s} in #{@unit.path} at line #{access.line}"
        lvalue.symbol_offset += field.offset
        {lvalue, field.constraint}
      else
        raise "Cannot access field #{access.field} on expression #{access.operand} of type #{constraint.to_s} in #{@unit.path} at line #{access.line}"
      end
    else 
      raise "Cannot compute lvalue for #{access.to_s} in #{@unit.path} at line #{access.line}"
    end
  end

  # Get the memory location of a global.
  def compile_global_lvalue(global : Unit::Global) : Memory
    dest_register = grab_register
    @text << Instruction.new(ISA::Lui, dest_register.value, immediate: assemble_immediate global.symbol, Kind::Lui).encode
    @text << Instruction.new(ISA::Addi, dest_register.value, dest_register.value, immediate: assemble_immediate global.symbol, Kind::Lli).encode
    Memory.absolute(dest_register)
  end

  # Get the memory location of a variable.
  def compile_variable_lvalue(variable : Variable) : Memory
    Memory.offset(variable.offset, variable)
  end

  # Get the memory location represented by an identifier.
  def compile_identifier_lvalue(identifier : AST::Identifier) : {Memory, Type::Any}
    variable = @variables[identifier.name]?
    if variable
      {compile_variable_lvalue(variable), variable.constraint}
    else
      global = @unit.globals[identifier.name]? || raise "Unknown identifier #{identifier.name} in #{@unit.path} at line #{identifier.line}"
      {compile_global_lvalue(global), global.type_info}             
    end
  end
  
  # Get the memory location represented by an expression.
  # This is limited to global, variable, dereferenced pointer and access to them.
  def compile_lvalue(expression : AST::Expression) : {Memory, Type::Any}?
    case expression
    when AST::Identifier then compile_identifier_lvalue expression
    when AST::Access then compile_access_lvalue expression
    when AST::Unary
      if expression.name == "*"
        pp "deref has no lvalue"
        destination_register = grab_register
        pp "Deref: compiling putting value in register #{destination_register}"
        constraint = compile_expression expression.operand, into: destination_register
        pp "Now derefencing it"
        if constraint.is_a? Type::Pointer || constraint.is_a? Type::Word # TODO remove, itwas just for lol
          {Memory.absolute(destination_register), constraint.is_a?(Type::Pointer) ? constraint.pointer_of : Type::Word.new} # TODO remove check
        else
          raise "Cannot dereference an expression of type #{constraint.to_s} in #{@unit.path} at line #{expression.line}"
        end
      else nil
      end
    else nil
    end
  end

  # Compile an assignement of any value to any other value.
  # The left side of the assignement must be solvable to a memory location (a lvalue).
  # The written value can also be written to another location (An assignement do have a type and an expression).
  def compile_assignement(left_side : AST::Expression, right_side : AST::Expression, into : Registers | Memory | Nil): Type::Any
    pp "Assignment, fetch lvalue"
    lvalue_result = compile_lvalue left_side
    lvalue_result || raise "Expression #{left_side.to_s} is not a valid left value for an assignement in #{@unit.path} at line #{left_side.line}"
    lvalue, destination_type = lvalue_result
    # Both lvalue and value to assign might be complex value  necessiting multiple temporary register to be used.
    # But we need both value at the same time.
    # So we compute the base address of the destination in a register and make this register the cache of a temporary value.
    # This way, if the register is grabbed, the register will be written to a reserved space before.
    # Move will read this value back in a register if it is cached.
    pp "Create TMP for lvalue address"
    with_temporary(lvalue.reference_register!, Type::Pointer.new destination_type) do |temporary|
      pp "TMP: #{temporary} cached in (#{temporary.register})"
      lvalue.reference_register = temporary
      pp "Now move rightside into memory at TMP"
      source_type = compile_expression right_side, into: lvalue
      if source_type != destination_type
        raise "Cannot assign expression of type #{source_type.to_s} to lvalue of type #{destination_type.to_s} in #{@unit.path} at line #{left_side.line}"
      end
    end
    move lvalue, destination_type, into: into if into
    destination_type
  end

  # Compile a binary operator value, and move it's value if necessary.
  def compile_binary(binary : AST::Binary, into : Registers | Memory | Nil): Type::Any?
    case binary.name
    when "=" then compile_assignement binary.left, binary.right, into: into
    else raise "UNSUPPORTED binary"
    end
  end

  # Compile the value of an access and move it's value if necessary.
  def compile_access(access : AST::Access,  into : Registers | Memory | Nil): Type::Any?
    memory, constraint = compile_access_lvalue access || raise "Illegal expression #{access.to_s} in #{@unit.path} at #{access.line}"
    move memory, constraint, into: into if into
    constraint
  end

  # Compile the value of any operation and move it's value if necessary.
  def compile_operator(operator : AST::Operator, into : Registers | Memory | Nil): Type::Any?
    case operator
    when AST::Unary then raise "UNSUPPORTED unary"
    when AST::Binary then compile_binary operator, into: into
    when AST::Access then compile_access operator, into: into
    end
  end
  
  # Compile the value of any expression and move it's value if necessary.
  def compile_expression(expression : AST::Expression, into : Registers | Memory | Nil): Type::Any?
    case expression
    when AST::Literal then compile_literal expression, into: into
    when AST::Identifier then compile_identifier expression, into: into
    when AST::Call then nil
    when AST::Operator then compile_operator expression, into: into
    end                                                          
  end

  # Compile the value of any expression and move it's value in the function return memory location.
  # Move the stack back and jump to return address.
  def compile_return(ret : AST::Return)
    if returned_value = ret.value
      if @return_type.nil?
        raise "Function #{@ast.name.name} at #{@unit.path} must return nothing, but return something at line #{ret.line}"
      else
        # offset for the return value to be written directly to the stack, in the place reserved for the return address
        returned_value_type = compile_expression returned_value, into: Memory.offset @return_value_offset.not_nil!.to_i32
        if @return_type.not_nil! != returned_value_type
          raise "Function #{@ast.name.name} at #{@unit.path} must return #{@return_type.to_s}, but return expression has type #{returned_value_type.try(&.to_s) || "nothing"} at line #{ret.line}"
        end
      end
    elsif @return_type
      raise "Function #{@ast.name.name} at #{@unit.path} must return #{@return_type.to_s}, but no return value is given at line #{ret.line}"
    end
    @text << Instruction.new(ISA::Lw, reg_a: RETURN_ADRESS_REGISTER.value, reg_b: STACK_REGISTER.value, immediate: @return_address_offset).encode
    @text << Instruction.new(ISA::Addi, reg_a: STACK_REGISTER.value, reg_b: STACK_REGISTER.value, immediate: @frame_size).encode
    @text << Instruction.new(ISA::Jalr, reg_a: 0u16, reg_b: RETURN_ADRESS_REGISTER.value).encode
  end

  # Compile any statement.
  def compile_statement(statement)
    case statement
    when AST::Return then compile_return statement   
    when AST::While then nil
    when AST::If then nil
    when AST::Expression then compile_expression statement, nil
    end
  end

  # Generate the section representing the instructions for the compiled functions.
  # TODO: find a wat to ensure every path end with a return.
  def compile : RiSC16::Object::Section
    # move the stack UP by the size of the stack frame.
    @text << Instruction.new(ISA::Addi, reg_a: STACK_REGISTER.value, reg_b: STACK_REGISTER.value, immediate: assemble_immediate -(@frame_size.to_i32), Kind::Imm).encode
    # copy the return address on the stack.
    @text << Instruction.new(ISA::Sw, reg_a: RETURN_ADRESS_REGISTER.value, reg_b: STACK_REGISTER.value, immediate: @return_address_offset).encode

    # Initialize variables
    @variables.values.each do |variable|
      if value = variable.initialization
        compile_assignement AST::Identifier.new(variable.name), value, nil
      end # We do not zero-initialize variable implicitely.
      variable.initialized = true
    end

    @ast.body.each do |statement|
      compile_statement statement
    end

    @section.text = Slice.new @text.size do |i| @text[i] end
    @text.clear
    @section
  end
  
end
