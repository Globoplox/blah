struct Stacklang::ThreeAddressCode::Translator
  # Regular assignement: a = 5
  def translate_assignement_as_move(expression : AST::Binary, left_override : {Address, Type}? = nil) : {Address, Type}?
    left = left_override || translate_expression expression.left

    if left.nil?
      @events.error(title: "Expression has no type", line: expression.left.token.line, column: expression.left.token.character) {}
      return
    end
    left_address, left_typeinfo = left

    right = translate_expression expression.right
    if right.nil?
      @events.error(title: "Expression has no type", line: expression.right.token.line, column: expression.right.token.character) {}
      return
    end
    right_address, right_typeinfo = right

    if left_typeinfo != right_typeinfo
      @events.error(title: "Type error", line: expression.token.line, column: expression.token.character) do |io|
        io << "Cannot assign value of type #{@events.emphasis(right_typeinfo.to_s)} to lvalue of type #{@events.emphasis(left_typeinfo.to_s)}"
      end
      return
    end

    @tacs << Move.new right_address, left_address, expression
    {right_address, right_typeinfo}
  end

  # Store assignement: *a = 5
  def translate_assignement_as_store(expression : AST::Binary, left_override : AST::Unary? = nil) : {Address, Type}?
    operand = (left_override || expression.left).as(AST::Unary).operand
    left = translate_expression operand
    if left.nil?
      @events.error(title: "Expression has no type", line: expression.left.token.line, column: expression.left.token.character) {}
      return
    end
    left_address, left_typeinfo = left

    unless left_typeinfo.is_a? Type::Pointer
      @events.error(title: "Type error", line: operand.token.line, column: operand.token.character) do |io|
        io << "Cannot dereference non-pointer type #{@events.emphasis(left_typeinfo.to_s)}"
      end
      return
    end
    left_typeinfo = left_typeinfo.pointer_of

    right = translate_expression expression.right
    if right.nil?
      @events.error(title: "Expression has no type", line: expression.right.token.line, column: expression.right.token.character) {}
      return
    end
    right_address, right_typeinfo = right

    if left_typeinfo != right_typeinfo
      @events.error(title: "Type error", line: expression.token.line, column: expression.token.character) do |io|
        io << "Cannot assign value of type #{@events.emphasis(right_typeinfo.to_s)} to lvalue of type #{@events.emphasis(left_typeinfo.to_s)}"
      end
      return
    end

    @tacs << Store.new left_address, right_address, expression

    {right_address, right_typeinfo}
  end

  def translate_assignment(expression : AST::Binary) : {Address, Type}?
    # A table access expression can be either substitued to a *(&l + r) expression
    # which is candidate for a store instead of a move.
    # However in some case it may also be automatically compiled to  an address as a no-op (in tacs terms)
    if expression.left.as?(AST::Binary).try(&.name.== "[")
      address = table_access_as_address? expression.left.as AST::Binary
      if address
        translate_assignement_as_move expression, left_override: address
      else
        translate_assignement_as_store expression, left_override: convert_table_access expression.left.as AST::Binary
      end
    elsif expression.left.as?(AST::Unary).try(&.name.== "*")
      translate_assignement_as_store expression
    else
      translate_assignement_as_move expression
    end
  end

  def translate_sugar_assignment(expression : AST::Binary, operator : String) : {Address, Type}?
    translate_expression AST::Binary.new(
      token: expression.token,
      left: expression.left,
      name: "=",
      right: AST::Binary.new(
        token: expression.token,
        left: expression.left,
        name: operator,
        right: expression.right
      )
    )
  end
end
