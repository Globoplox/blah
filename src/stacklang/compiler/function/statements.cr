class Stacklang::Function

  # Compile the value of any expression and move it's value in the function return memory location.
  # Move the stack back and jump to return address.
  def compile_return(ret : AST::Return)
    if returned_value = ret.value
      if @return_type.nil?
        error "Must return nothing, but return something at line", node: ret
      else
        # offset for the return value to be written directly to the stack, in the place reserved for the return address
        returned_value_type = compile_expression returned_value, into: Memory.offset @return_value_offset.not_nil!.to_i32
        if @return_type.not_nil! != returned_value_type
          error "Must return #{@return_type.to_s}, but return expression has type #{returned_value_type.try(&.to_s) || "nothing"}", node: ret
        end
      end
    elsif @return_type
      error "Must return #{@return_type.to_s}, but no return value is given", node: ret
    end
    @text << Instruction.new(ISA::Lw, reg_a: RETURN_ADRESS_REGISTER.value, reg_b: STACK_REGISTER.value, immediate: @return_address_offset).encode
    @text << Instruction.new(ISA::Addi, reg_a: STACK_REGISTER.value, reg_b: STACK_REGISTER.value, immediate: @frame_size).encode
    @text << Instruction.new(ISA::Jalr, reg_a: 0u16, reg_b: RETURN_ADRESS_REGISTER.value).encode
  end

  # Compile a if or while statement.
  def compile_if(if_node : AST::If | AST::While, loop = false)
    # Symbol name (local uniq with debug info encoded)
    symbol_start = "__while_start_#{@local_uniq += 1}_#{Base64.encode(if_node.condition.to_s[0..13])}"
    symbol_end = "__while_end_#{@local_uniq += 1}_#{Base64.encode(if_node.condition.to_s[0..13])}"
    # Store all
    store_all
    result_register = grab_register
    @section.definitions[symbol_start] = Object::Section::Symbol.new @text.size, false if loop
    # Compute condition
    condition_type = compile_expression if_node.condition, into: result_register
    error "Condition expression expect a word or a pointer, got #{condition_type}", node: if_node if condition_type.is_a?(Type::Struct)
    # beq r0 result (if false) jump to +1
    @text << Instruction.new(ISA::Beq, reg_a: result_register.value, immediate: 1u16).encode
    # beq TRUE jump to after we setup and jump to the end
    @text << Instruction.new(ISA::Beq, immediate: 3u16).encode
    # movi result < __if_end__
    @text << Instruction.new(ISA::Lui, result_register.value, immediate: assemble_immediate symbol_end, Kind::Lui).encode
    @text << Instruction.new(ISA::Addi, result_register.value, result_register.value, immediate: assemble_immediate symbol_end, Kind::Lli).encode
    # jalr r0 result
    @text << Instruction.new(ISA::Jalr, reg_b: result_register.value).encode
    # compile body
    if_node.body.each do |statement|
      compile_statement statement
    end
    # store_all
    store_all
    # jmp symbol_start
    if loop
      @text << Instruction.new(ISA::Lui, result_register.value, immediate: assemble_immediate symbol_start, Kind::Lui).encode
      @text << Instruction.new(ISA::Addi, result_register.value, result_register.value, immediate: assemble_immediate symbol_start, Kind::Lli).encode
      @text << Instruction.new(ISA::Jalr, reg_b: result_register.value).encode
    end
    # define __if_end__ here
    @section.definitions[symbol_end] = Object::Section::Symbol.new @text.size, false    
  end
  
  # Compile any statement.
  def compile_statement(statement)
    case statement
    when AST::Return then compile_return statement   
    when AST::If then compile_if statement
    when AST::While then compile_if statement, loop: true
    when AST::Expression then compile_expression statement, nil
    end
  end

  
end
