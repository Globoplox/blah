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
    lw RETURN_ADRESS_REGISTER, STACK_REGISTER, @return_address_offset.to_i32
    addi STACK_REGISTER, STACK_REGISTER, @frame_size.to_i32
    jalr Registers::R0, RETURN_ADRESS_REGISTER
  end

end