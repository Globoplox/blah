class Stacklang::Native::Generator  

  # TODO: Heavy optimization could be done by use single instead of bad => load => jalr
  # when possible.
  def compile_jump_eq(code : ThreeAddressCode::JumpEq)

    operands = code.operands
    if operands
      if operands[0].size != operands[1].size
        raise "Size mismatch in allocation #{code}"
      end
    end

    if operands && operands[0].size != 1
      raise "Size mismatch in allocation #{code}"
    end
    # TODO: it is WHOLY HARDER if not size 1 :(
  
    # We will jump to a label. 
    # At label location, no value is assumed as being cached.
    # So before jumping, any value not written to ram must be spilled before.

    # Before unloading potential usefull addresses, save where they are cached
    left_register = right_register = nil
    if operands
      left_register = @addresses[root_id operands.not_nil![0]].live_in_register(operands.not_nil![0])
      right_register = @addresses[root_id operands.not_nil![1]].live_in_register(operands.not_nil![1])
    end

    # Unload them.
    # Unloading never use any registers that is susceptible of hosting something so the registers
    # we saved before still have the value we want them to after unloading
    unload_all

    if operands
      # Now, if they wern't loaded, we load them (but we dont save the cache so they dont get uselessly spilled after ?)
      left_register ||= load operands[0], avoid: [right_register].compact
      right_register ||= load operands[1], avoid: [left_register].compact
    end    
    
    # LOAD THE LABEL (name in code.location)

    if left_register && right_register
      load_immediate FILL_SPILL_REGISTER, code.location
      beq left_register, right_register, 1 # If equal, jump (goto jalr)
      beq ZERO_REGISTER, ZERO_REGISTER, 1 # Else, do not jump (skip jalr)
      jalr ZERO_REGISTER, FILL_SPILL_REGISTER
    else
      load_immediate FILL_SPILL_REGISTER, code.location
      jalr ZERO_REGISTER, FILL_SPILL_REGISTER
    end
  end
end
