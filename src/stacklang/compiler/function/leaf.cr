class Stacklang::Function

  # Generate code necessary to move a single-word literal value in any location.
  def compile_literal(literal : AST::Literal, into : Registers | Memory | Nil): Type::Any
    # An expression composed of just a literal is useless (it can't have a side effect).
    return Type::Word.new if into.nil?
    case into
    when Registers
      movi into, literal.number
    when Memory
      tmp_register = into.within_var.try(&.register) || grab_register excludes: [into.reference_register] # FIXME: use used_registers ? Might be useless.
      # Only case where it is usefull is when ref_register hold address (either return where its R7 and ungrabable, or assignment and it's protected by tmp var)
      # This is true for all grab within rightside valuen unless they don't rely on move: should they try to protect ino ?
      # This might be useless but might reduce register/caching/storage. IDK.
      movi tmp_register, literal.number
      # The move will compute to no-op automatically if this ends up copying a register to itself.
      move tmp_register, Type::Word.new, into
    end
    Type::Word.new
  end

  # Generate code necessary to move a sizeof literal value in any location.
  def compile_sizeof(ast : AST::Sizeof, into : Registers | Memory | Nil): Type::Any
    # An expression composed of just a literal is useless (it can't have a side effect).
    return Type::Word.new if into.nil?
    compile_literal AST::Literal.new(@unit.typeinfo(ast.constraint).size.to_i32), into: into
  end

  # Generate code necessary to move a global variable value in any location.
  def compile_global(global : Unit::Global, into : Registers | Memory | Nil): Type::Any
    # An expression composed of just a global is useless (it can't have a side effect).
    return Type::Word.new if into.nil?
    source = compile_global_lvalue global
    move source, global.type_info, into
    global.type_info
  end

  # Generate code necessary to move a variable value in any location.
  def compile_variable(variable : Variable, into : Registers | Memory | Nil): Type::Any
    # An expression composed of just a variable is useless (it can't have a side effect).
    return Type::Word.new if into.nil?
    error "Cannot use variable #{variable.name} before it is initalized" unless variable.initialized
    source = compile_variable_lvalue variable
    move source, variable.constraint, into
    variable.constraint
  end

  # Generate code necessary to move any value represened by an identifier in any location.
  def compile_identifier(identifier : AST::Identifier, into : Registers | Memory | Nil): Type::Any
    # An expression composed of just an identifier is useless (it can't have a side effect).
    return Type::Word.new if into.nil?
    variable = @variables[identifier.name]?
    if variable
      compile_variable variable, into: into
    else
      global = @unit.globals[identifier.name]?
      global || error "Unknown identifier #{identifier.name}", node: identifier 
      compile_global global, into: into
    end
  end

  # Compile the value of an access and move it's value if necessary.
  def compile_access(access : AST::Access,  into : Registers | Memory | Nil): Type::Any
    memory, constraint = compile_access_lvalue access || raise "Illegal expression #{access.to_s} in #{@unit.path} at #{access.line}"
    move memory, constraint, into: into if into
    constraint
  end

end
