require "../../risc16"
require "./types"
require "./unit"

# TODO: handle copy with index in a temporary register with a beq loop ?
# that would be much better than these infamous dump of lw sw
# which will fail when the size is biger than 64 anyway

# Opti: when doing a movi and the value is a flat 0, we could do a sw r0, ,0 instead of a movi

# Likely should have a dedicated function for generating movi

# Code cleanup could be to have the move accept register destination

# Function to generate error

# Lnaguage feature: function ptr, cast

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
    property initialized
    @offset : Int32 # offset to the stack frame
    @name : String
    @constraint : Type::Any
    @initialization : AST::Expression?

    getter name
    getter constraint
    getter offset
    getter initialization

    # Carefull, no zero init
    def initialize(@name, @offset, @constraint, @initialization)
      @initialized = @initialization.nil?
    end
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

  #TODO: delete
  @locked = [] of Registers
  
  getter prototype

  # Extract the prototype data. Offset are relative to stack frame of the callee, not the caller
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

  # Ensure a variable value is written to ram and not in a cache so the register can be used for something else
  def store(variable)
    variable.register.try do |register|
      lvalue = compile_variable_lvalue variable
      move register, variable.constraint, lvalue, force_to_memory: true
    end
  end
  
  def grab_register(excludes = [] of Registers)
    pp "Grabbing register"
    free = (GPR - excludes - @locked - @variables.values.compact_map(&.register).uniq)[0]?
    return free if free
    selected = (GPR - excludes - @locked).shuffle.first
    @variables.values.each do |variable|
      if variable.register == selected
        store variable
        variable.register = nil
      end
    end
    selected
  end

  # Represent a memory location relative to a register
  # That can be read or written from
  class Memory
    property symbol_offset : Int32 # offset to symbol_offset but work also when value is a string
    getter value : Int32 | String # the offset to reference_register
    getter reference_register : Registers # the register containing the address
    getter within_var : Variable? # used to identify that the ram correspond to a var, that could be currently cached into a register

    # a = a + 1
    # + will ask register loading of both values
    # a will be loaded and cached in register (single lw)
    # 1 is cached into single register (movi)
    # result is then cached in a single register
    # a = will load lvalue of a
    # then move register -> lvalue
    # but we could decide that lvalue is a register if a ise already loaded into one
    # then lvalue would be a register and we could just either add lvalue result r0 or even just say that
    # var.register = new one (that work only if move know it is var, not just the register associed)
    # Also: access could also return a cachable lvalue if we allow var to have a hash of fields to 'fictous subvar' that can have a register

    # overall: move value into 
    # value can be a REGISTER when: result of operand, or MEMORY with a cached var when: it is a cached var, cached access
    # into can be a REGISTER when: we setup param of operand, or MEMORY with a cached var when: it is a cached var, cached access
    # When we into a memory with a var, and the value fit a register / is already in a register, we can just say this register is now the cache of a var
    # instead of performing move    

    # Then the grab_register will actually need the "store var if cached" piece of code
    # Because move DO CAN move into a register instead of the memory.

    # ALSO: stack need another additional place for temporay value. That would act as a special variable
    # so when doing (stuff1) + (stuff2) we compute stuff1 into the temporary_var (which a move can set as cached)
    # and so when computing stuff2, if a lot of register are needed, it can grab the one caching the value and grab_register will store the value into
    # the tmp var.

    # BUT! (stuff1) + (stuff2) if we compute stuff1 first, maybe stuff2 will itself, within its computation, require a tmp_var.
    # so instead we need a growing stack of tmp_var, that are register cached by default but might not always be.
    # when we are done compute (stuff1) + (stuff2) we release all tmp_var created yet.

    # Temp var are special in the way that they have negative offset to the stack.
    # So a call would overwrite them.
    # So when performing a call, all tmp_var must be wrote to ram (all var must, infact all register are cleaned)
    # then the stack must move to the top of tmp vars, call is performed.
    # stack is moved back. Carefull if fetching the return address: it as offset - size of temp vars !
    
    
    def initialize(@reference_register, @value, @symbol_offset, @within_var) end

    def self.offset(value : Int32, var : Variable? = nil)
      new STACK_REGISTER, value, 0, var
    end

    def self.absolute(register : Registers, value : Int32 | String = 0, symbol_offset : Int32 = 0)
      new register, value, symbol_offset, nil
    end
  end

  # Generate code to move data.
  # When it can, it read/write from/to cache register
  def move(memory : Memory | Registers, constraint : Type::Any, into : Memory | Registers, force_to_memory = false)
    pp "Move #{memory} to #{into}"
    memory = memory.within_var.try(&.register) || memory if memory.is_a? Memory
    
    case {memory, into}
    when {Registers, Registers}
      pp "move reg to reg"
      @text << Instruction.new(ISA::Add, into.value, memory.value).encode unless into == memory

    when {Registers, Memory}
      pp "move reg #{memory} to ram #{into.reference_register} + #{into.value} + #{into.symbol_offset}"
      pp "Ram target correspond to var #{into.within_var} of type #{into.within_var.try &.constraint.to_s}"
      if force_to_memory == false && (var = into.within_var) && var.constraint.size == 1
        # if into is actually a cachable var, we can simply set source regsiter as its cache
        var.register = memory
      else
        # this is the case happening when storing. Storing never need to grab a register so it can't stack overflow.
        
        # no need to uncache, because is uncachable and shouldn't have been cached ever
        @text << Instruction.new(ISA::Sw, memory.value, into.reference_register.value, immediate: assemble_immediate into.value, Kind::Imm, into.symbol_offset).encode
      end

    when {Memory, Registers}
      pp "move ram to reg"
      # case where memory is a cached var is already handled by the memory = ... || memory
      raise "Illegal move of multiple word into register" if constraint.size > 1
      @text << Instruction.new(ISA::Lw, into.value, memory.reference_register.value, immediate: assemble_immediate memory.value, Kind::Imm, memory.symbol_offset).encode

    when {Memory, Memory}
      pp "move ram to ram"
      pp "move ram #{memory.reference_register} + #{memory.value} + #{memory.symbol_offset} to ram #{into.reference_register} + #{into.value} + #{into.symbol_offset}"

      if force_to_memory == false &&  (var = into.within_var) && var.constraint.size == 1
        # let's update or create the cache.
        target_register = var.register || grab_register excludes: [memory.reference_register]
        @text << Instruction.new(
          ISA::Lw, target_register.value, memory.reference_register.value, immediate: assemble_immediate memory.value, Kind::Imm, memory.symbol_offset
        ).encode
        var.register = target_register

      else
        # TODO: if force_to_memory == false and we find out both location are the same, no need to compile anything.
        
        # no need to uncache, because is uncachable and shouldn't have been cached ever
        tmp_register = grab_register excludes: [into.reference_register, memory.reference_register]
        (0...(constraint.size)).each do |index|
          @text << Instruction.new(
            ISA::Lw, tmp_register.value, memory.reference_register.value, immediate: assemble_immediate memory.value, Kind::Imm, memory.symbol_offset + index
          ).encode
          @text << Instruction.new(
            ISA::Sw, tmp_register.value, into.reference_register.value, immediate: assemble_immediate into.value, Kind::Imm, into.symbol_offset + index
          ).encode
        end
        
      end
    end
  end

  def compile_literal(literal : AST::Literal, into : Registers | Memory | Nil): Type::Any?
    return nil if into.nil? # An expression composed of just a literal is useless (it can't have a side effect)
    case into
    when Registers
      @text << Instruction.new(ISA::Lui, into.value, immediate: assemble_immediate literal.number, Kind::Lui).encode
      @text << Instruction.new(ISA::Addi, into.value, into.value, immediate: assemble_immediate literal.number, Kind::Lli).encode
    when Memory
      tmp_register = into.within_var.try(&.register) || grab_register excludes: [into.reference_register]
      pp "put literal in reg #{tmp_register}"
      @text << Instruction.new(ISA::Lui, tmp_register.value, immediate: assemble_immediate literal.number, Kind::Lui).encode
      @text << Instruction.new(ISA::Addi, tmp_register.value, tmp_register.value, immediate: assemble_immediate literal.number, Kind::Lli).encode
      if (var = into.within_var) && var.constraint.size == 1
        pp "make this register cache of #{var}"
        var.register = tmp_register
      else
        pp "store this reg in ram #{into}"
        @text << Instruction.new(ISA::Sw, tmp_register.value, into.reference_register.value, immediate: assemble_immediate into.value, Kind::Imm, into.symbol_offset).encode
      end
    end
    Type::Word.new
  end

  def compile_global(global : Unit::Global, into : Registers | Memory | Nil): Type::Any?
    return nil if into.nil? # An expression composed of just a global is useless (it can't have a side effect)
    source = compile_global_lvalue global
    move source, global.type_info, into
    global.type_info
  end

  def compile_variable(variable : Variable, into : Registers | Memory | Nil): Type::Any?
    return nil if into.nil? # An expression composed of just an identifier is useless (it can't have a side effect)
    raise "Cannot use variable #{variable.name} before it is initalized" unless variable.initialized
    source = compile_variable_lvalue variable
    move source, variable.constraint, into 
    variable.constraint
  end

  def compile_identifier(identifier : AST::Identifier, into : Registers | Memory | Nil): Type::Any?
    return nil if into.nil? # An expression composed of just an identifier is useless (it can't have a side effect)
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

  # Get the memory location and type of an access expression
  def compile_access_lvalue(access : AST::Access) : {Memory, Type::Any}?
    lvalue_result = compile_lvalue access.operand
    if lvalue_result
      lvalue, constraint = lvalue_result
      if constraint.is_a? Type::Struct
        field = constraint.fields.find &.name.== access.field.name
        field || raise "No such field #{access.field.name} for struct #{constraint.to_s} in #{@unit.path} at line #{access.line}"
        lvalue.symbol_offset += field.offset
        # we don't build another memory. If initial memory was a var, it is still noted so move know it's within a var and must note
        # it might noy be cached anymore
        # TODO: create subvar for fields so var field can be cached too.
        # when done gotta be careful about struct of size 1: both the struct and the field could have the same "register" cache.
        # so for these case, the field subvariable should be a backref to the parent struct. But then what happen if multiples level ?
        # will probably need to make the Variable type smarter
        {lvalue, field.constraint}
      else
        raise "Cannot access field #{access.field} on expression #{access.operand} of type #{constraint.to_s} in #{@unit.path} at line #{access.line}"
      end
    else 
      raise "Cannot compute lvalue for #{access.to_s} in #{@unit.path} at line #{access.line}"
    end
  end

  # Get a memory location for a global
  def compile_global_lvalue(global : Unit::Global) : Memory
    dest_register = grab_register
    @text << Instruction.new(ISA::Lui, dest_register.value, immediate: assemble_immediate global.symbol, Kind::Lui).encode
    @text << Instruction.new(ISA::Addi, dest_register.value, dest_register.value, immediate: assemble_immediate global.symbol, Kind::Lli).encode
    Memory.absolute(dest_register)
  end

  # Get a memory location for a variable
  def compile_variable_lvalue(variable : Variable) : Memory
    Memory.offset(variable.offset, variable)
  end

  # Get a momeory location for an identifier
  def compile_identifier_lvalue(identifier : AST::Identifier) : {Memory, Type::Any}
    variable = @variables[identifier.name]?
    if variable
      {compile_variable_lvalue(variable), variable.constraint}
    else
      global = @unit.globals[identifier.name]? || raise "Unknown identifier #{identifier.name} in #{@unit.path} at line #{identifier.line}"
      {compile_global_lvalue(global), global.type_info}             
    end
  end
  
  # Try to obtain a memory location from an expression.
  def compile_lvalue(expression : AST::Expression) : {Memory, Type::Any}?
    case expression
    when AST::Identifier then compile_identifier_lvalue expression
    when AST::Access then compile_access_lvalue expression
      
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
            pp "Dereferencement produce ram address #{lvalue.reference_register}"
            {Memory.absolute(lvalue.reference_register), constraint.pointer_of}
          else
            raise "Cannot dereference an expression of type #{constraint.to_s} in #{@unit.path} at line #{expression.line}"
          end
        else
          destination_register = grab_register
          constraint = compile_expression expression.operand, into: destination_register
          if constraint.is_a? Type::Pointer || constraint.is_a? Type::Word # TODO remove, itwas just for lol
            # maybe also allow words with a warning ?
            @text << Instruction.new(ISA::Lw, destination_register.value, destination_register.value).encode
            {Memory.absolute(destination_register), constraint.is_a?(Type::Pointer) ? constraint.pointer_of : Type::Word.new} # TODO remove check
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
    # Issue: our lvalue might depend on a register that is necessary to be kept until we have processed our right_side
    # But right_side is not aware that we have this requirement.
    # and might use this same register.
    # simply providing an excludes list and/or managing local locked register list
    # would not be enough: in complex instruction, we might lock and lock and run out of register
    # like a = b = c = d = e = f = 5 then when loading 5 we would need a register but each global would have produce an lvalue relative
    # to a register it locked, game over.
    # this is the same problem as 1+2+3+4+5+6, that should be solved with tmp val that can be stacked to release registers.
    # this is easy because chainable operators works only on words
    #   (a value safe before computing its right side)

    # the real solution here wold be to allow Memory to use a temporary var
    #   (so a registers but with an offset to stack to cache it if register is needed for something else) as a

    # tmp fix to test that this register reuse is really the issue: (this crash for expression that contain more than 5 to 6 assignements)
    @locked.push lvalue.reference_register 
    source_type = compile_expression right_side, into: lvalue
    @locked.pop
    
    if source_type != destination_type
      raise "Cannot assign expression of type #{source_type.to_s} to lvalue of type #{destination_type.to_s} in #{@unit.path} at line #{left_side.line}"
    end

    case into
    when Registers
      raise "Cannot load multiple-word term in register. Check that you are not dereferencing a struct." if destination_type.size > 1
      @text << Instruction.new(ISA::Lw, into.value, lvalue.reference_register.value, immediate: assemble_immediate lvalue.value, Kind::Imm, lvalue.symbol_offset).encode
    when Memory then
      move lvalue, destination_type, into: into
    end

    destination_type
  end

  def compile_binary(binary : AST::Binary, into : Registers | Memory | Nil): Type::Any?
    case binary.name
    when "=" then compile_assignement binary.left, binary.right, into: into
    else raise "UNSUPPORTED binary"
    end
  end

  def compile_access(access : AST::Access,  into : Registers | Memory | Nil): Type::Any?
    return nil unless into
    memory, constraint = compile_access_lvalue access || raise "Illegal expression #{access.to_s} in #{@unit.path} at #{access.line}"
    case into
    when Registers
      raise "Cannot load multiple-word term in register. Check that you are not dereferencing a struct." if constraint.size > 1
      @text << Instruction.new(ISA::Lw, into.value, memory.reference_register.value, immediate: assemble_immediate memory.value, Kind::Imm, memory.symbol_offset).encode
    when Memory
      move memory, constraint, into: into
    end
    constraint
  end
  
  def compile_operator(operator : AST::Operator, into : Registers | Memory | Nil): Type::Any?
    case operator
    when AST::Unary then raise "UNSUPPORTED unary"
    when AST::Binary then compile_binary operator, into: into
    when AST::Access then compile_access operator, into: into
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
        pp "return memory: R7 + #{@return_value_offset.not_nil!}"
        returned_value_type = compile_expression returned_value, into: Memory.offset @return_value_offset.not_nil!.to_i32
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
  def compile : RiSC16::Object::Section
    # move the stack UP by the size of the stack frame
    @text << Instruction.new(ISA::Addi, reg_a: STACK_REGISTER.value, reg_b: STACK_REGISTER.value, immediate: assemble_immediate -(@frame_size.to_i32), Kind::Imm).encode
    # copy the return address on the stack
    @text << Instruction.new(ISA::Sw, reg_a: RETURN_ADRESS_REGISTER.value, reg_b: STACK_REGISTER.value, immediate: @return_address_offset).encode

    # Initialize variables
    @variables.values.each do |variable|
      if value = variable.initialization
        compile_assignement AST::Identifier.new(variable.name), value, nil
      else
        # Zero init variables ?
        # If yes: less unpredicatable behavior
        # If no: it cost zero instruction
      end
      variable.initialized = true
    end

    # Compile body
    @ast.body.each do |statement|
      compile_statement statement
    end

    @section.text = Slice.new @text.size do |i| @text[i] end
    @text.clear
    @section
  end
  
end
