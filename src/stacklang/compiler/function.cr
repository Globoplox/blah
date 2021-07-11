require "../../risc16"
require "./types"
require "./unit"

# TODO: handle copy with index in a temporary register with a beq loop ?
# that would be much better than these infamous dump of lw sw
# which will fail when the size is biger than 64 anyway
# Also now with the Memory type, dumping a memory location to another can be made generic to reduce a little
# the size of this file.
class Stacklang::Function
  include RiSC16
  alias Kind = Object::Section::Reference::Kind
  
  enum Registers : UInt16
    R0
    R1
    R2
    R3
    R4
    R5
    R6
    R7
  end

  GPR = [Registers::R1, Registers::R2, Registers::R3, Registers::R4, Registers::R5, Registers::R6]

  STACK_REGISTER = Registers::R7
  RETURN_ADRESS_REGISTER = Registers::R6 # Calling convention: the return address is initialy stored in r6

  class Variable
    property register : Registers? = nil
    property initialized = true # because we ignore initialisation for now
    @offset : Int32 # offset to the stack frame
    @name : String
    @constraint : Type::Any
    #@initialisation ignored rn

    getter name
    getter constraint
    getter offset
    
    def initialize(@name, @offset, @constraint) end
  end
    
  class Prototype # All offsets are relative to the CALLER stack
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

  # All offsets are relative to the CALLEE stack (the current one once we have performed the very first instruction of the function).
  @ast : AST::Function
  @unit : Unit
  @prototype : Prototype
  @variables : Hash(String, Variable) 
  @return_type : Type::Any?
  @frame_size : UInt16 = 0u16
  @return_value_offset : UInt16? = nil
  @section : RiSC16::Object::Section  
  @text = [] of UInt16

  getter prototype

  # Extract the prototype data. Offset are relative to stack frame of the callee, not the caller
  def initialize(@ast, @unit)
    @return_type = ast.return_type.try { |r| @unit.typeinfo r }

    local_variables = @ast.variables.map do |variable|
      typeinfo = @unit.typeinfo variable.constraint
      Variable.new(variable.name.name, @frame_size.to_i32, typeinfo).tap do
        @frame_size += typeinfo.size
      end
      # we ignore initialisation rn
    end
    
    parameters = @ast.parameters.map do |parameter|
      typeinfo = @unit.typeinfo parameter.constraint
      Variable.new(parameter.name.name, @frame_size.to_i32, typeinfo).tap do 
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

  # Helper function for assembling immediate value
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
  
  # There could be a lot of optimization here
  # A quick easy one, would be to try to grab register used by variable that have not been used in a long time 
  def grab_register(excludes = [] of Registers)
    selected = (GPR - excludes).shuffle.first
    @variables.values.each do |variable|
      # no need to "sync" to stack: only a '=' can affect a value on stack and it is always synced 
      variable.register = nil if variable.register == selected
    end
    selected
  end

  class Memory
    property symbol_offset : Int32 # offset to symbol_offset but work also when value is a string
    getter value : Int32 | String # the offset to reference_register
    getter reference_register : Registers # the register containing the address
    def initialize(@reference_register, @value, @symbol_offset) end

    def self.offset(value : Int32)
      new STACK_REGISTER, value, 0
    end

    def self.absolute(register : Registers, value : Int32 | String = 0, symbol_offset : Int32 = 0)
      new register, value, symbol_offset
    end
  end
  
  # Compile a literal.
  # Produce the code necessary to put the literal value in a register or an offset.
  # Return the type of the literal.
  def compile_literal(literal : AST::Literal, into : Registers | Memory | Nil): Type::Any?
    return nil if into.nil? # An expression composed of just a literal is useless (it can't have a side effect)
    case into

    when Registers
      @text << Instruction.new(ISA::Lui, into.value, immediate: assemble_immediate literal.number, Kind::Lui).encode
      @text << Instruction.new(ISA::Addi, into.value, into.value, immediate: assemble_immediate literal.number, Kind::Lli).encode

    when Memory
      tmp_register = grab_register excludes: [into.reference_register]
      @text << Instruction.new(ISA::Lui, tmp_register.value, immediate: assemble_immediate literal.number, Kind::Lui).encode
      @text << Instruction.new(ISA::Addi, tmp_register.value, tmp_register.value, immediate: assemble_immediate literal.number, Kind::Lli).encode
      @text << Instruction.new(ISA::Sw, tmp_register.value, into.reference_register.value, immediate: assemble_immediate into.value, Kind::Imm, into.symbol_offset).encode

    end
    Type::Word.new
  end


  def compile_global(global : Unit::Global, into : Registers | Memory | Nil): Type::Any?
    return nil if into.nil? # An expression composed of just a global is useless (it can't have a side effect)
    case into

    when Registers
      raise "Cannot load multiple-word variable in register. Check that you are not dereferencing a struct." if global.type_info.size > 1
      # load address of global (we use the target register as a buffer)
      @text << Instruction.new(ISA::Lui, into.value, immediate: assemble_immediate global.symbol, Kind::Lui).encode
      @text << Instruction.new(ISA::Addi, into.value, into.value, immediate: assemble_immediate global.symbol, Kind::Lli).encode
      # dereference
      @text << Instruction.new(ISA::Lw, into.value, into.value).encode

    when Memory # same as offset, same as absolute, but consider destination adress already loaded
      # load address of global
      source_register = grab_register excludes: [into.reference_register] # will contain the global address
      @text << Instruction.new(ISA::Lui, source_register.value, immediate: assemble_immediate global.symbol, Kind::Lui).encode
      @text << Instruction.new(ISA::Addi, source_register.value, source_register.value, immediate: assemble_immediate global.symbol, Kind::Lli).encode
      # reserve temporary register
      tmp_register = grab_register excludes: [into.reference_register, source_register]
      (0...(global.type_info.size)).each do |index|
        # safer version would
        # grab a tmp, movi the real offset, add it into ref register
        #then use tmp to inc and add to both register (unless ref_reg is stack, then another temp should be used as cache)
        @text << Instruction.new(ISA::Lw, tmp_register.value, source_register.value, immediate: assemble_immediate index, Kind::Imm).encode
        @text << Instruction.new(ISA::Sw, tmp_register.value, into.reference_register.value, immediate: assemble_immediate into.value, Kind::Imm, into.symbol_offset + index).encode
      end
    end
    
    global.type_info
  end
  
  def compile_identifier(identifier : AST::Identifier, into : Registers | Memory | Nil): Type::Any?
    return nil if into.nil? # An expression composed of just an identifier is useless (it can't have a side effect)
    variable = @variables[identifier.name]?
    if variable.nil?
      global = @unit.globals[identifier.name]?
      global || raise "Unknown identifier #{identifier.name} in #{@unit.path} at line #{identifier.line}" 
      return compile_global global, into: into
    end
    raise "Cannot use variable #{identifier.name} before it is initalized" unless variable.initialized
    case {into, variable.register}

    when {Registers, Registers} # Reg => Register
      raise "Cannot load multiple-word variable in register. Check that you are not dereferencing a struct." if variable.constraint.size > 1
      @text << Instruction.new(ISA::Add, into.value, variable.register.not_nil!.value).encode unless variable.register == into
      variable.register = into

    when {Registers, Nil} # Stack => Register
      raise "Cannot load multiple-word variable in register. Check that you are not dereferencing a struct." if variable.constraint.size > 1
      @text << Instruction.new(ISA::Lw, into.value, STACK_REGISTER.value, immediate: assemble_immediate variable.offset, Kind::Imm).encode
      variable.register = into

    when {Memory, Registers} # Registers  => Ram
      raise "Cannot read multiple-word variable from register" if variable.constraint.size > 1 # Should never happen.
      @text << Instruction.new(ISA::Sw, variable.register.not_nil!.value, into.reference_register.value, assemble_immediate into.value, Kind::Imm, into.symbol_offset).encode

    when {Memory, Nil} # Stack => Ram
      # maybe remove gurad, likely useless. Same optimization could be done for global with some kind of beq but annoying.
      # unless into.reference_register.r7? and into.value == variable.offset
        tmp_register = grab_register excludes: [into.reference_register]
        (0...(variable.constraint.size)).each do |index|
          @text << Instruction.new(ISA::Lw, tmp_register.value, STACK_REGISTER.value, immediate: assemble_immediate variable.offset + index, Kind::Imm).encode
          @text << Instruction.new(ISA::Sw, tmp_register.value, into.reference_register.value, immediate: assemble_immediate into.value, Kind::Imm, into.symbol_offset + index).encode
        end
      # end
    end
    variable.constraint
  end

  # def compile_call(call : AST::Call, into : Registers | Offset | Nil): Type::Any?
  #   # find the func prototype
  #   function = @unit.functions[identifier.name.name]? || "Unknown functions #{identifier.name} in #{@unit.path} at line #{call.line}"

  #   # check that we are not trying to put a multiple word return value into a register
  #   # for each paramter: copy into futur stack
  #   # call
  #   # depending on the into, copy the return value
  # end


  # Try to obtain a memory location from an expression.
  def compile_lvalue(expression : AST::Expression) : {Memory, Type::Any}?
    case expression

    when AST::Identifier
      variable = @variables[expression.name]?
      if variable
        {Memory.offset(variable.offset), variable.constraint}
      else
        global = @unit.globals[expression.name]? || raise "Unknown identifier #{expression.name} in #{@unit.path} at line #{expression.line}"
        dest_register = grab_register
        @text << Instruction.new(ISA::Lui, dest_register.value, immediate: assemble_immediate global.symbol, Kind::Lui).encode
        @text << Instruction.new(ISA::Addi, dest_register.value, dest_register.value, immediate: assemble_immediate global.symbol, Kind::Lli).encode
        {Memory.absolute(dest_register), global.type_info}
      end

    when AST::Access
      lvalue_result = compile_lvalue expression.operand
      if lvalue_result
        lvalue, constraint = lvalue_result
        if constraint.is_a? Type::Struct
          field = constraint.fields.find &.name.== expression.field.name
          field || raise "No such field #{expression.field.name} for struct #{constraint.to_s} in #{@unit.path} at line #{expression.line}"
          lvalue.symbol_offset += field.offset
          {lvalue, field.constraint}
        else
          raise "Cannot access field #{expression.field} on expression #{expression.operand} of type #{constraint.to_s} in #{@unit.path} at line #{expression.line}"
        end
      else 
        raise "Cannot compute lvalue for #{expression.to_s} in #{@unit.path} at lien #{expression.line}"
      end
      
    when AST::Unary
      if expression.name == "*"
        # si dereferencement
        # on compute juste la lvalue et on dereference.
        # Si ca a pas de lvalue possible (genre valeur de retour d'un call, my_ptr + 1 ou chépakoi), alors compile dans un registre et creer la memory a partir de
        # ce registre. Dans tout les cas ont peux pas dereference autre chose qu'un pointeur donc le type devrait TOUJOURS rentrer dans un registre.
        # *(&toto) = <=> toto (c'est la compilation de '&' qui stock dans son into l'address.

        lvalue_result = compile_lvalue expression.operand
        if lvalue_result
          lvalue, constraint = lvalue_result
          if constraint.is_a? Type::Pointer
            # maybe also allow words with a warning ?
            @text << Instruction.new(ISA::Lw, lvalue.reference_register.value, lvalue.reference_register.value, immediate: assemble_immediate lvalue.value, Kind::Imm, lvalue.symbol_offset).encode
            {Memory.absolute(lvalue.reference_register), constraint.pointer_of}
          else
            raise "Cannot dereference an expression of type #{constraint.to_s} in #{@unit.path} at line #{expression.line}"
          end
        else
          destination_register = grab_register
          constraint = compile_expression expression.operand, into: destination_register
          if constraint.is_a? Type::Pointer
            # maybe also allow words with a warning ?
            @text << Instruction.new(ISA::Lw, destination_register.value, destination_register.value).encode
            {Memory.absolute(destination_register), constraint.pointer_of}
          else
            raise "Cannot dereference an expression of type #{constraint.to_s} in #{@unit.path} at line #{expression.line}"
          end

        end
      else
        nil
      end
    else nil
    end
  end

  def compile_assignement(left_side : AST::Expression, right_side : AST::Expression, into : Registers | Memory | Nil): Type::Any
    lvalue_result = compile_lvalue left_side
    lvalue_result || raise "Expression #{left_side.to_s} is not a valid left value for an assignement in #{@unit.path} at line #{left_side.line}"
    lvalue, destination_type = lvalue_result
    source_type = compile_expression right_side, into: lvalue

    if source_type != destination_type
      raise "Cannot assign expression of type #{source_type.to_s} to lvalue of type #{destination_type.to_s} in #{@unit.path} at line #{left_side.line}"
    end
    
    # TODO: then if there is an into copy from lvalue to into (for (foo = bar) + 2 kind of expression)
    raise "UNSUPPORTED Cannot use affection value for now" if into
    destination_type
  end

  def compile_binary(binary : AST::Binary, into : Registers | Memory | Nil): Type::Any?
    case binary.name
    when "=" then compile_assignement binary.left, binary.right, into: into
    else raise "UNSUPPORTED binary"
    end
  end
  
  def compile_operator(operator : AST::Operator, into : Registers | Memory | Nil): Type::Any?
    case operator
    when AST::Unary then raise "UNSUPPORTED unary"
    when AST::Binary then compile_binary operator, into: into
    when AST::Access then raise "UNSUPPORTED access"
    end
  end
  
  def compile_expression(expression : AST::Expression, into : Registers | Memory | Nil): Type::Any?
    case expression
    when AST::Literal then compile_literal expression, into: into
    when AST::Identifier then compile_identifier expression, into: into
    when AST::Call then nil
    when AST::Operator then compile_operator expression, into: into
    end                                                          
  end

  def compile_return(ret : AST::Return)
    # Compute and store return value if any
    if returned_value = ret.value
      if @return_type.nil?
        raise "Function #{@ast.name.name} at #{@unit.path} must return nothing, but return something at line #{ret.line}"
      else
        # offset for the return value to be written directly to the stack, in the place reserved for the return address
        returned_value_type = compile_expression returned_value, into: Memory.offset  @return_value_offset.not_nil!.to_i32
        if @return_type.not_nil! != returned_value_type
          raise "Function #{@ast.name.name} at #{@unit.path} must return #{@return_type.to_s}, but return expression has type #{returned_value_type.try(&.to_s) || "nothing"} at line #{ret.line}"
        end
      end
    elsif @return_type
      raise "Function #{@ast.name.name} at #{@unit.path} must return #{@return_type.to_s}, but no return value is given at line #{ret.line}"
    end

    # Load the return address
    @text << Instruction.new(ISA::Lw, reg_a: RETURN_ADRESS_REGISTER.value, reg_b: STACK_REGISTER.value, immediate: @return_address_offset).encode

    # We move the stack back
    @text << Instruction.new(ISA::Addi, reg_a: STACK_REGISTER.value, reg_b: STACK_REGISTER.value, immediate: @frame_size).encode

    # jump back. The responsability of fetching the return value is up to the caller if it want to.
    @text << Instruction.new(ISA::Jalr, reg_a: 0u16, reg_b: RETURN_ADRESS_REGISTER.value).encode
  end

  def compile_statement(statement)
    case statement
    when AST::Return then compile_return statement   
    when AST::While then nil
    when AST::If then nil
    when AST::Expression then compile_expression statement, nil
    end
  end

  # TODO: find a wat to ensure every path end with a return ?
  # TODO: initialize variables ?
  def compile : RiSC16::Object::Section
    # move the stack UP by the size of the stack frame
    @text << Instruction.new(ISA::Addi, reg_a: STACK_REGISTER.value, reg_b: STACK_REGISTER.value, immediate: assemble_immediate -(@frame_size.to_i32), Kind::Imm).encode
    # copy the return address on the stack
    @text << Instruction.new(ISA::Sw, reg_a: RETURN_ADRESS_REGISTER.value, reg_b: STACK_REGISTER.value, immediate: @return_address_offset).encode

    # Then: initialize variables

    @ast.body.each do |statement|
      compile_statement statement
    end

    @section.text = Slice.new @text.size do |i| @text[i] end
    @text.clear
    @section
  end
  
end
