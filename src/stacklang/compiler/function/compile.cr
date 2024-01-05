class Stacklang::Function
  def predict_size
    old_refs = @section.references
    old_defs = @section.definitions
    old_text = @text
    @text = [] of UInt16
    @section.definitions = {} of String => RiSC16::Object::Section::Symbol
    @section.references = {} of String => Array(RiSC16::Object::Section::Reference)
    yield
    text_size = @text.size
    @text = old_text
    @section.definitions = old_defs
    @section.references = old_refs
    text_size
  end

  # Run a computation step while ensuring a register value is kept or cached in stack.
  # To be used with #uncache or #move.
  def with_temporary(register : Registers, constraint : Type::Any)
    tmp = Variable.new "__temporary_var_#{@temporaries.size}", -(@temporaries.size + 1), constraint, nil, restricted: true
    tmp.register = register
    @temporaries.push tmp
    ret = yield tmp
    @temporaries.pop
    ret
  end

  # Ensure a variable value is written to ram and not in a cache so the register can be used for something else.
  def store(variable)
    variable.register.try do |register|
      lvalue = compile_variable_lvalue variable
      move register, variable.constraint, lvalue, force_to_memory: true
    end
  end

  # Ensure all variables avlues are written to the ram, including temporaries.
  def store_all
    (@temporaries + @variables.values).each do |variable|
      store variable
      variable.register = nil
    end
  end

  # Cache a variable in a register.
  # Used to fetch temporary variables, or to get the actual value of a variable.
  # If the variable can be cached (restricted or temporary), the register is kept linked to
  # the variable so next time we need the value of the variable, we can reuse this register.
  # If the register is needed for something else, it will be automatically unlinked and persisted to ram (by `grab_register`).
  def cache(variable, excludes) : Registers
    variable.register || begin
      register = grab_register excludes: excludes
      lw register, STACK_REGISTER, variable.offset
      variable.register = register if variable.restricted
      register
    end
  end

  def is_free_to_use(register)
    (register.in? GPR) && !(register.in? @temporaries.compact_map(&.register) - @variables.values.compact_map(&.register))
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

  # Check a block to ensure that it terminates.
  def check_termination(body : Array(AST::Statement))
    return false if body.empty?
    last = body[-1]
    case last
    when AST::Return then true
    when AST::If, AST::While then check_termination last.body
    else false
    end
  end

  # Generate the section representing the instructions for the compiled functions.
  # TODO: find a way to ensure every path end with a return.
  def compile : RiSC16::Object::Section
    raise "Function '#{name}' is extern and should not be compiled" if @extern
    unless check_termination @ast.body
      if @return_type
        raise "Function '#{name}'returning #{@return_type} does not always return"
      else
        @ast.body << AST::Return.new @ast.token, nil
      end
    end

    # move the stack UP by the size of the stack frame.
    addi STACK_REGISTER, STACK_REGISTER, -(@frame_size.to_i32)
    # copy the return address on the stack.
    sw RETURN_ADRESS_REGISTER, STACK_REGISTER, @return_address_offset.to_i32

     # We do NOT zero-initialize variable implicitely.

    @ast.body.each do |statement|
      compile_statement statement
    end

    @section.text = Slice.new @text.size do |i|
      @text[i]
    end
    @text.clear
    @section
  end
end
