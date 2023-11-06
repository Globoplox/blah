class Stacklang::Function
  # Get the memory location and type represented an access.
  # This work by obtaining a memory location for its subvalue and adding the accessed field offset.
  def compile_access_lvalue(access : AST::Access) : {Memory, Type::Any}?
    lvalue_result = compile_lvalue access.operand
    if lvalue_result
      lvalue, constraint = lvalue_result
      if constraint.is_a? Type::Struct
        field = constraint.fields.find &.name.== access.field.name
        field || error "No such field #{access.field.name} for struct #{constraint}", node: access
        lvalue.value += field.offset
        {lvalue, field.constraint}
      else
        error "Cannot access field #{access.field} on expression #{access.operand} of type #{constraint}", node: access
      end
    else
      error "Cannot compute lvalue for #{access}", node: access
    end
  end

  # Get the memory location of a global.
  def compile_global_lvalue(global : Unit::Global) : Memory
    dest_register = grab_register
    movi dest_register, global.symbol
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
      global = @unit.globals[identifier.name]? || error "Unknown identifier #{identifier.name}", node: identifier
      {compile_global_lvalue(global), global.type_info}
    end
  end

  # Get the memory location represented by an expression.
  # This is limited to global, variable, dereferenced pointer and access to them.
  # TODO: Optimization when we do not need the Memory target and only care for side effect ?
  def compile_lvalue(expression : AST::Expression) : {Memory, Type::Any}?
    case expression
    when AST::Identifier then compile_identifier_lvalue expression
    when AST::Access     then compile_access_lvalue expression
    when AST::Cast       then compile_lvalue(expression.target).try { |lvalue| {lvalue[0], @unit.typeinfo(expression.constraint)} }
    when AST::Unary, AST::Binary
      if expression.is_a?(AST::Binary) && expression.name == "["
        expression = AST::Unary.new(AST::Binary.new(AST::Unary.new(expression.left, "&"), "+", expression.right), "*")
      end
      if expression.is_a?(AST::Unary) && expression.name == "*"
        # TODO: use Any register destination instead of grabbing one ?
        destination_register = grab_register
        constraint = compile_expression expression.operand, into: destination_register
        if constraint.is_a? Type::Pointer
          {Memory.absolute(destination_register), constraint.pointer_of}
        else
          error "Cannot dereference an expression of type #{constraint}", node: expression
        end
      else
        nil
      end
    else nil
    end
  end

  # Compile an assignement of any value to any other value.
  # The left side of the assignement must be solvable to a memory location (a lvalue).
  # The written value can also be written to another location (An assignement do have a type and an expression).
  def compile_assignment(left_side : AST::Expression, right_side : AST::Expression, into : Registers | Memory | Nil) : Type::Any
    lvalue_result = compile_lvalue left_side
    lvalue_result || raise "Expression #{left_side.to_s} is not a valid left value for an assignement in #{@unit.path} at line #{left_side.line}"
    lvalue, destination_type = lvalue_result
    # Both lvalue and value to assign might be complex value  necessiting multiple temporary register to be used.
    # But we need both value at the same time.
    # So we compute the base address of the destination in a register and make this register the cache of a temporary value.
    # This way, if the register is grabbed, the register will be written to a reserved space before.
    # Move will read this value back in a register if it is cached.
    with_temporary(lvalue.reference_register!, Type::Pointer.new destination_type) do |temporary|
      lvalue.reference_register = temporary
      source_type = compile_expression right_side, into: lvalue
      if source_type != destination_type
        error "Cannot assign expression of type #{source_type} to lvalue of type #{destination_type}", node: right_side
      end
    end
    move lvalue, destination_type, into: into if into
    destination_type
  end
end
