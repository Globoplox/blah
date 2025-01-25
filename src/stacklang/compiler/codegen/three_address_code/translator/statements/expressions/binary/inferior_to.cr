struct Stacklang::ThreeAddressCode::Translator
  def translate_inferior_to(expression : AST::Binary, jumps : ConditionalJumps, or_equal = false, inverse = false)
    left = translate_expression expression.left
    if left.nil?
      raise Exception.new "Expression has no type", expression.left, @function
    end

    right = translate_expression expression.right
    if right.nil?
      raise Exception.new "Expression has no type", expression.right, @function
    end

    left_address, left_typeinfo = left
    right_address, right_typeinfo = right

    case {left_typeinfo, right_typeinfo}
      when {Type::Word, Type::Word} then Type::Word.new
      when {Type::Word, Type::Pointer} then right_typeinfo
      when {Type::Pointer, Type::Word} then left_typeinfo
      else raise Exception.new "Cannot add values of types #{left_typeinfo} and #{right_typeinfo}", expression, @function
    end

    if_true = jumps.if_true
    if_false = jumps.if_false

    # a < b
    # a - b < 0
    # So if we substract a and b
    # and check if the SIGN BIT of the result is SET then true
    # if (a - b) & 0x8000 == 0 THEN jump_false

    if or_equal
      @tacs << JumpEq.new(jumps.if_true, {left_address, right_address}, expression)
    end

    if inverse
      if_true, if_false = if_false, if_true
    end

    t0 = anonymous 1
    @tacs << Nand.new right_address, right_address, t0, expression
    t1 = anonymous 1
    @tacs << Add.new t0, Immediate.new(1,  expression), t1, expression
    t2 = anonymous 1
    @tacs << Add.new left_address, t1, t2, expression
    
    t3 = Immediate.new 0x8000, expression
    t4 = anonymous 1
    @tacs << Nand.new t2, t3, t4, expression
    t5 = anonymous 1
    @tacs << Nand.new t4, t4, t5, expression

    # t5 == (a - b) & 0x8000

    # if ((a - b) & 0x8000) == 0 AKA a - b > 0 AKA a < b == false
    @tacs << JumpEq.new(if_false, {t5, Immediate.new(0,  expression)}, expression)
    @tacs << JumpEq.new(if_true, nil, expression)
  end
end