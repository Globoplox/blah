class Stacklang::Function

  def compile_addition(left_side : {Registers, Type::Any}, right_side : {Registers, Type::Any} , into : Registers | Memory, node : AST::Node, soustract = false): Type::Any
    left_side_register, left_side_type = left_side
    right_side_register, right_side_type = right_side
    ret_type = case {left_side_type, right_side_type}
      when {Type::Word, Type::Word} then Type::Word.new
      when {Type::Pointer, Type::Word} then left_side_type
      when {Type::Word, Type::Pointer} then right_side_type
      else error "Cannot add values of types #{left_side_type} and #{right_side_type} together", node: node
    end
    result_register = grab_register excludes: [left_side_register, right_side_register]# TODO: maybe protect into for optimal code ?
    # It is not critical, only case is is not R7 relative are from assignment lvalue and they are tmp val protected.
    if soustract
      nand result_register, right_side_register, right_side_register
      addi result_register,result_register, 1
      right_side_register = result_register
    end
    add result_register, left_side_register, right_side_register
    move result_register, ret_type, into: into
    ret_type
  end

  def compile_bitwise_and(left_side : {Registers, Type::Any}, right_side : {Registers, Type::Any} , into : Registers | Memory, node : AST::Node, inv = false): Type::Any
    left_side_register, left_side_type = left_side
    right_side_register, right_side_type = right_side
    ret_type = case {left_side_type, right_side_type}
      when {Type::Word, Type::Word} then Type::Word.new
      else error "Cannot apply 'bitewise nand' to values of types #{left_side_type} and #{right_side_type} together", node: node
    end 
    result_register = grab_register excludes: [left_side_register, right_side_register]
    nand result_register, left_side_register, right_side_register
    nand result_register, result_register, result_register unless inv
    move result_register, ret_type, into: into
    ret_type
  end

  def compile_bitwise_or(left_side : {Registers, Type::Any}, right_side : {Registers, Type::Any} , into : Registers | Memory, node : AST::Node, inv = false): Type::Any
    left_side_register, left_side_type = left_side
    right_side_register, right_side_type = right_side
    ret_type = case {left_side_type, right_side_type}
      when {Type::Word, Type::Word} then Type::Word.new
      else error "Cannot apply 'bitewise or' to values of types #{left_side_type} and #{right_side_type} together", node: node
    end 
    result_register_1 = grab_register excludes: [left_side_register, right_side_register]
    nand result_register_1, left_side_register, left_side_register
    result_register_2 = grab_register excludes: [right_side_register, result_register_1]
    nand result_register_2, right_side_register, right_side_register
    result_register = result_register_1 # Could have been 2, does not matter.
    nand result_register, result_register_1, result_register_2
    nand result_register, result_register, result_register if inv
    move result_register, ret_type, into: into
    ret_type
  end
  
  # TODO: Allow ptr comparison ?
  # FIXME: should not compute right side if left side is falsy
  def compile_logic_and(left_side : {Registers, Type::Any}, right_side : {Registers, Type::Any} , into : Registers | Memory, node : AST::Node): Type::Any
    left_side_register, left_side_type = left_side
    right_side_register, right_side_type = right_side
    ret_type = case {left_side_type, right_side_type}
      when {Type::Word, Type::Word} then Type::Word.new
      else error "Cannot compare two values of types #{left_side_type} and #{right_side_type}", node: node
    end
    result_register = grab_register excludes: [left_side_register, right_side_register]
    add result_register, result_register, Registers::R0
    beq left_side_register, Registers::R0, 0x2
    beq right_side_register, Registers::R0, 0x1
    add result_register, right_side_register, Registers::R0
    move result_register, Type::Word.new, into: into
    Type::Word.new
  end

  # TODO: Allow ptr comparison ?
  # FIXME: should not compute right side if left side is truthy
  def compile_logic_or(left_side : {Registers, Type::Any}, right_side : {Registers, Type::Any} , into : Registers | Memory, node : AST::Node): Type::Any
   compile_bitwise_or left_side, right_side, into, node 
  end
  
  # TODO: Add long type equal ?
  # TODO: Allow ptr comparison ?
  def compile_equal(left_side : {Registers, Type::Any}, right_side : {Registers, Type::Any} , into : Registers | Memory, node : AST::Node, neq = false): Type::Any
    left_side_register, left_side_type = left_side
    right_side_register, right_side_type = right_side
    ret_type = case {left_side_type, right_side_type}
      when {Type::Word, Type::Word} then Type::Word.new
      else error "Cannot compare two values of types #{left_side_type} and #{right_side_type}", node: node
    end
    result_register = grab_register excludes: [left_side_register, right_side_register]
    unless neq
      addi result_register, Registers::R0, 1
      beq left_side_register, right_side_register, 1u16
      add result_register, Registers::R0, Registers::R0
    else
      add result_register, Registers::R0, Registers::R0
      beq left_side_register, right_side_register, 1u16
      addi result_register, Registers::R0, 1
    end
    move result_register, ret_type, into: into
    ret_type
  end

  def compile_comparator(left_side : {Registers, Type::Any}, right_side : {Registers, Type::Any} , into : Registers | Memory, node : AST::Node,  superior_to = false, or_equal = false): Type::Any
    left_side_register, left_side_type = left_side
    right_side_register, right_side_type = right_side
    ret_type = case {left_side_type, right_side_type}
      when {Type::Word, Type::Word} then Type::Word.new
      else error "Cannot compare two values of types #{left_side_type} and #{right_side_type}", node: node
    end
    result_register = grab_register excludes: [left_side_register, right_side_register]
    left_side_register, right_side_register = {right_side_register, left_side_register} if superior_to
    # we inv right_side
    nand result_register, right_side_register, right_side_register
    addi result_register, result_register, 1
    # we do the soustraction itself
    add result_register, left_side_register, result_register
    # prepare comparison
    tmp_register = grab_register excludes: [left_side_register, right_side_register, result_register]
    movi tmp_register, 0x8000
    nand tmp_register, result_register, tmp_register
    nand tmp_register, tmp_register, tmp_register
    raise "Comparion with OR_EQUAL do not works yet" if or_equal
    # if tmp register hold 0x8000 it is true
    # else it holds zero, it is false. Tmp register hold the result.
    # if or_equal
    #   # donc result & 0xffff => 0 que si result != 0 (donc sir result == 0, donne truthy) <= COULD REWORK == to use this to avoid beq     
    #   literal_register = grab_register excludes: [left_side_register, right_side_register, result_register, tmp_register]
    #   movi literal_register, 0xffff
    #   nand result_register, result_register, literal_register      
    #   # then or tmp and result
    #   nand tmp_register, tmp_register, tmp_register
    #   nand result_register, result_register, result_register
    #   nand tmp_register, tmp_register,result_register
    # end
    move tmp_register, left_side_type, into: into
    Type::Word.new
  end
  
  def compile_binary_to_call(binary : AST::Binary, into : Registers | Memory | Nil): Type::Any
    call_name = case binary.name
    when "<<" then "left_bitshift"
    when ">>" then "right_bitshift"
    else error "Usupported binary operator '#{binary.name}'", node: binary
    end
    call = AST::Call.new(AST::Identifier.new(call_name), [binary.left, binary.right])
    call.line = binary.line
    call.character = binary.character
    compile_call call, into: into
  end

  def compile_sugar_assignment(binary : AST::Binary, into : Registers | Memory | Nil): Type::Any
    sugared = binary.name.rchop "="
    compile_assignment binary.left,  AST::Binary.new(binary.left, sugared, binary.right), into: into
  end

  def compile_table_access(binary : AST::Binary, into : Registers | Memory | Nil): Type::Any
    compile_expression AST::Unary.new(AST::Binary.new(AST::Unary.new(binary.left, "&"), "+", binary.right), "*"), into: into
  end

  def compile_binary(binary : AST::Binary, into : Registers | Memory | Nil): Type::Any
    if into.nil?
      compile_expression binary.left, into: nil
      compile_expression binary.right, into: nil
      Type::Word.new
    else
      left_side_register = grab_register excludes: into.used_registers
      left_side_type = compile_expression binary.left, into: left_side_register
      error "Cannot perform binary #{binary.name} operation with left-side expression of type nothing", node: binary unless left_side_type
      with_temporary(left_side_register, left_side_type) do |temporary|
        right_side_register = grab_register excludes: into.used_registers + [left_side_register]
        right_side_type = compile_expression binary.right, into: right_side_register
        left_side_register = cache temporary, excludes: [right_side_register]
        left_side = {left_side_register, left_side_type}
        right_side = {right_side_register, right_side_type}
        case binary.name
        when "+" then compile_addition left_side, right_side, into: into, node: binary
        when "-" then compile_addition left_side, right_side, into: into, node: binary, soustract: true
        when "&" then compile_bitwise_and left_side, right_side, into: into, node: binary
        when "&&" then compile_logic_and left_side, right_side, into: into, node: binary
        when "||" then compile_logic_or left_side, right_side, into: into, node: binary
        when "~&" then compile_bitwise_and left_side, right_side, into: into, node: binary, inv: true
        when "|" then compile_bitwise_or left_side, right_side, into: into, node: binary
        when "~|" then compile_bitwise_or left_side, right_side, into: into, node: binary, inv: true
        when "==" then compile_equal left_side, right_side, into: into, node: binary
        when "!=" then compile_equal left_side, right_side, into: into, node: binary, neq: true
        when ">" then compile_comparator left_side, right_side, node: binary, into: into, superior_to: true
        # when ">=" then compile_comparator left_side, right_side, node: binary, into: into, superior_to: true, or_equal: true
        when "<" then compile_comparator left_side, right_side, node: binary, into: into
        # when "<=" then compile_comparator left_side, right_side, node: binary, into: into, or_equal: true
        else error "Unusupported binary operation '#{binary.name}'", node: binary
        end
      end
    end
  end
  
  # Compile a binary operator value, and move it's value if necessary.
  def compile_assignment_or_binary(binary : AST::Binary, into : Registers | Memory | Nil): Type::Any
    case binary.name
    when "=" then compile_assignment binary.left, binary.right, into: into
    when "<<", ">>", "*", "/" then compile_binary_to_call binary, into: into
    when "[" then compile_table_access binary, into: into 
    when "+=", "-=", "&=", "~=", "|=", "<<=", ">>=" then compile_sugar_assignment binary, into: into
    else compile_binary binary, into: into
    end
  end
  
end
