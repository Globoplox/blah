require "../../risc16"
require "./types"
require "./unit"

# TODO: handle copy with index in a temporary register with a beq loop ?
# that would be much better than these infamous dump of lw sw
# which will fail when the size is biger than 64 anyway
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
  
  # CALLING CONVENTION:
  # CALLEE MUST INCREASE STACK POINTER 
  # CALLEE PASS PARAMETER ON THE STACK
  # CALLER MUST PUT RETURN ADDRESS IN R6
  # CALLER MUST RESTORE SAVED REGISTERS HIMESELF

  # Variable with a size > 1 are never cached
  # because it make no sense
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
  def assemble_immediate(immediate, kind)
    if immediate.is_a? String
      references = @section.references[immediate] ||= [] of Object::Section::Reference
      references << Object::Section::Reference.new @text.size.to_u16, 0, kind
      0u16
    else
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

  # Represent an addres, offset to the stack. Can be used to represent:
  # - a variable
  # - a field of a variable
  # - a paramter of a futur call
  # - the return value of current function
  class Offset
    getter offset : Int32
    # def self.for_self_variable(variable, fields = [] of Identifier)  
    # end

    # def self.for_futur_call(prototype, parameter_name)
    #   # offset is going to be negative:
    #   # current_stack_ptr (our 0) - called function stack_frame_size + parameter offset  
    # end

    def initialize(@offset) end
  end

  # Reprensent an absolute address
  class Absolute
    getter value : Int32 | String
    def initialize(@value) end
  end

  # Compile a literal.
  # Produce the code necessary to put the literal value in a register or an offset.
  # Return the type of the literal.
  def compile_literal(literal : AST::Literal, into : Registers | Offset | Nil): Type::Any?
    return nil if into.nil? # An expression composed of just a literal is useless (it can't have a side effect)
    case into

    when Registers
      @text << Instruction.new(ISA::Lui, into.value, immediate: assemble_immediate literal.number, Kind::Lui).encode
      @text << Instruction.new(ISA::Addi, into.value, into.value, immediate: assemble_immediate literal.number, Kind::Lli).encode

    when Offset
      tmp_register = grab_register
      @text << Instruction.new(ISA::Lui, tmp_register.value, immediate: assemble_immediate literal.number, Kind::Lui).encode
      @text << Instruction.new(ISA::Addi, tmp_register.value, tmp_register.value, immediate: assemble_immediate literal.number, Kind::Lli).encode
      @text << Instruction.new(ISA::Sw, tmp_register.value, STACK_REGISTER.value, immediate: assemble_immediate into.offset, Kind::Imm).encode

    when Absolute
      tmp_register = grab_register
      @text << Instruction.new(ISA::Lui, tmp_register.value, immediate: assemble_immediate literal.number, Kind::Lui).encode
      @text << Instruction.new(ISA::Addi, tmp_register.value, tmp_register.value, immediate: assemble_immediate literal.number, Kind::Lli).encode
      dest_register = grab_register excludes: [tmp_register]
      @text << Instruction.new(ISA::Lui, dest_register.value, immediate: assemble_immediate into.value, Kind::Lui).encode
      @text << Instruction.new(ISA::Addi, dest_register.value, dest_register.value, immediate: assemble_immediate into.value, Kind::Lli).encode
      @text << Instruction.new(ISA::Sw, tmp_register.value, dest_register.value).encode

    end
    Type::Word.new
  end


  def compile_global(global : Unit::Global, into : Registers | Offset | Absolute | Nil): Type::Any?
    return nil if into.nil? # An expression composed of just a global is useless (it can't have a side effect)
    case into

    when Registers
      raise "Cannot load multiple-word variable in register" if global.type_info.size > 1
      # load address of global (we use the target register as a buffer)
      @text << Instruction.new(ISA::Lui, into.value, immediate: assemble_immediate global.symbol, Kind::Lui).encode
      @text << Instruction.new(ISA::Addi, into.value, into.value, immediate: assemble_immediate global.symbol, Kind::Lli).encode
      # dereference
      @text << Instruction.new(ISA::Lw, into.value, into.value).encode

    when Offset
      # load address of global
      source_register = grab_register # will contain the global address
      @text << Instruction.new(ISA::Lui, source_register.value, immediate: assemble_immediate global.symbol, Kind::Lui).encode
      @text << Instruction.new(ISA::Addi, source_register.value, source_register.value, immediate: assemble_immediate global.symbol, Kind::Lli).encode
      # reserve temporary register
      tmp_register = grab_register excludes: [source_register]
      # load destination address
      dest_register = STACK_REGISTER
      # copy
      (0...(global.type_info.size)).each do |index|
        @text << Instruction.new(ISA::Lw, tmp_register.value, source_register.value, assemble_immediate index, Kind::Imm).encode
        @text << Instruction.new(ISA::Sw, tmp_register.value, dest_register.value, immediate: assemble_immediate into.offset + index, Kind::Imm).encode
      end

    when Absolute
      # load address of global
      source_register = grab_register # will contain the global address
      @text << Instruction.new(ISA::Lui, source_register.value, immediate: assemble_immediate global.symbol, Kind::Lui).encode
      @text << Instruction.new(ISA::Addi, source_register.value, source_register.value, immediate: assemble_immediate global.symbol, Kind::Lli).encode
      # reserve temporary register
      tmp_register = grab_register excludes: [source_register] # will contain the value to transfer
      # load destination address
      dest_register = grab_register excludes: [source_register, tmp_register] # will contain the destination addess
      @text << Instruction.new(ISA::Lui, dest_register.value, immediate: assemble_immediate into.value, Kind::Lui).encode
      @text << Instruction.new(ISA::Addi, dest_register.value, dest_register.value, immediate: assemble_immediate into.value, Kind::Lli).encode
      # copy
      (0...(global.type_info.size)).each do |index|
        @text << Instruction.new(ISA::Lw, tmp_register.value, source_register.value, immediate: assemble_immediate index, Kind::Imm).encode
        @text << Instruction.new(ISA::Sw, tmp_register.value, dest_register.value, immediate: assemble_immediate index, Kind::Imm).encode
      end
    end
    global.type_info
  end
  
  def compile_identifier(identifier : AST::Identifier, into : Registers | Offset | Absolute | Nil): Type::Any?
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
      raise "Cannot load multiple-word variable in register" if variable.constraint.size > 1
      @text << Instruction.new(ISA::Add, into.value, variable.register.not_nil!.value).encode unless variable.register == into
      variable.register = into

    when {Registers, Nil} # Stack => Register
      raise "Cannot load multiple-word variable in register" if variable.constraint.size > 1
      @text << Instruction.new(ISA::Lw, into.value, STACK_REGISTER.value, assemble_immediate variable.offset, Kind::Imm).encode
      variable.register = into

    when {Offset, Registers} # Registers  => Stack
      raise "Cannot read multiple-word variable from register" if variable.constraint.size > 1
      @text << Instruction.new(ISA::Sw, variable.register.not_nil!.value, STACK_REGISTER.value, assemble_immediate into.offset, Kind::Imm).encode

    when {Offset, Nil} # Stack => Stack
      unless into.as(Offset).offset == variable.offset # no need to move stuff in it's current place
        tmp_register = grab_register
        (0...(variable.constraint.size)).each do |index| # basically a memcpy
          @text << Instruction.new(ISA::Lw, tmp_register.value, STACK_REGISTER.value, assemble_immediate variable.offset + index, Kind::Imm).encode
          @text << Instruction.new(ISA::Sw, tmp_register.value, STACK_REGISTER.value, assemble_immediate into.offset + index, Kind::Imm).encode
        end
      end

    when {Absolute, Registers} # Register => Ram
      raise "Cannot read multiple-word variable from register" if variable.constraint.size > 1
      # load destination address
      dest_register = grab_register # will contain the destination addess
      @text << Instruction.new(ISA::Lui, dest_register.value, immediate: assemble_immediate into.value, Kind::Lui).encode
      @text << Instruction.new(ISA::Addi, dest_register.value, dest_register.value, immediate: assemble_immediate into.value, Kind::Lli).encode
      # write
      @text << Instruction.new(ISA::Sw, variable.register.not_nil!.value, dest_register.value).encode

    when {Absolute, Nil} # Stack => Ram
      # load destination address
      dest_register = grab_register # will contain the destination addess
      @text << Instruction.new(ISA::Lui, dest_register.value, immediate: assemble_immediate into.value, Kind::Lui).encode
      @text << Instruction.new(ISA::Addi, dest_register.value, dest_register.value, immediate: assemble_immediate into.value, Kind::Lli).encode
      # reserve temporary register
      tmp_register = grab_register excludes: [dest_register] # will contain the value to transfer
      (0...(variable.constraint.size)).each do |index|
        @text << Instruction.new(ISA::Lw, tmp_register.value, STACK_REGISTER.value, assemble_immediate variable.offset + index, Kind::Imm).encode
        @text << Instruction.new(ISA::Sw, tmp_register.value, dest_register.value, assemble_immediate index, Kind::Imm).encode
      end
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

  def compile_lvalue(expression : AST::Expression) : {Offset | Absolute, Type::Any}
    case expression
    when AST::Identifier
    # var => offset
    # global => absolute
    # si access: compute la lvalue,
      # si absolute/offset, add l'offset a la valeur (devrai rajouter un champ offset a zero sur absolute a stocker avec la ref au symbol)
    # si dereferencement
      # compile la valeur dans un registre SI POSSIBLE, sinon dans un offset ou un absolute (faudra rajouter un type d'into pour dire "le plus simple" et retourner l'into)
      # si c'est un registre, faudra un nouveau type en plus de offset/absolute pour specifier le registre a utiliser
        # ou alors trouver un moyen de les fusioners en un truc)
      # la fonction "le plus simple" pourrait etre une overload pour différent type
    # sinon interdit. par ex le retour d'un call: ne peux pas etre affecté, doit d'abord etre copié dans une variable. (par contre
      # on peux faire (identifer = call()).field = value normalement
    else raise "Expression #{expression.to_s} is not a valid left value for an assignement in #{@unit.path} at line #{expression.line}"
  end

  def compile_assignement(left_side : AST::Expression, right_side : AST::Expression, into: Registers | Offset | Absolute | Nil): Type::Any
    lvalue = compile_lvalue left_size
    compile_expression right_size, into: lvalue
    # then if there is an into copy from lvalue to into
  end

  def compile_binary(binary : AST::Binary, into: Registers | Offset | Absolute | Nil): Type::Any?
    case binary.name
    when "=" then compile_assignement binary.left, binary.right, into: into
    else nil
    end
  end
  
  def compile_operator(operator : AST::Operator, into: Registers | Offset | Absolute | Nil): Type::Any?
    case operator
    when AST::Unary then nil
    when AST::Binary then compile_binary operator, into: into
    when AST::Access then nil
    end
  end
  
  def compile_expression(expression : AST::Expression, into : Registers | Offset | Absolute | Nil): Type::Any?
    case expression
    when AST::Literal then compile_literal expression, into: into
    when AST::Identifier then compile_identifier expression, into: into
    when AST::Call then nil
    when AST::Operator then compile_operator expression, into: into
      if 
    end                                                          
  end

  def compile_return(ret : AST::Return)
    # Compute and store return value if any
    if returned_value = ret.value
      if @return_type.nil?
        raise "Function #{@ast.name.name} at #{@unit.path} must return nothing, but return something at line #{ret.line}"
      else
        # offset for the return value to be written directly to the stack, in the place reserved for the return address
        offset = Offset.new @return_value_offset.not_nil!.to_i32
        returned_value_type = compile_expression returned_value, into: offset
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
    when AST::Expression then nil
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
