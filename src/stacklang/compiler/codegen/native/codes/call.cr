class Stacklang::Native::Generator
  def compile_call(code : ThreeAddressCode::Call)
    # Must fix the stack size before copying all parameters
    # this mean all parameters and the call address must have a stack location (if they are spilled or not does not matter yet)
    # so load/unload operation during copy dont change the stack size
    param_registers = [] of Register
    (code.parameters.map(&.first) + [code.address]).each do |address|
      meta = @addresses[root_id address]
      if meta.spillable.yes? || meta.spillable.always?
        meta.live_in_register(address).try { |register| param_registers << register }
        stack_allocate address unless meta.spilled_at
      end
    end

    # We must unload everything else (same reason, ensure stack do not change size)
    unload_all GPR - param_registers

    stack_size = @stack.size

    # Then, copy them to the expected call location
    stack_size = @stack.size
    code.parameters.each do |(address, copy_offset)|
      # Parameters are either already loaded, or already have a stack address
      # Any other address that is not a parameter is not cached
      # So there is no risk of growing the stack when  loading the parameters
      if address.size == 1
        param_reg = load address
        if !overflow_immediate_offset? stack_size + copy_offset
          sw param_reg, STACK_REGISTER, stack_size + copy_offset
        else
          load_immediate FILL_SPILL_REGISTER, stack_size + copy_offset
          add FILL_SPILL_REGISTER, STACK_REGISTER, FILL_SPILL_REGISTER
          sw param_reg, FILL_SPILL_REGISTER, 0
        end
      else
        raise "Multi word parameter not yet supported"
      end
    end

    # Parameters are copied, and the call will destroy caches
    # BUT the call address which must stay loaded (if it is)
    param_registers.clear
    code.parameters.each do |(address, _)|
      meta = @addresses[root_id address]
      if meta.spillable.yes? || meta.spillable.always?
        meta.live_in_register(address).try { |register| param_registers << register }
      end
    end
    unload_all param_registers
    clear read: code.parameters.map(&.first), written: [] of ThreeAddressCode::Address

    # Now everything unloaded BUT maybe the call address.
    # We must spill it (in case it is somehting like a local variable assigned previously whose value is hosted but not spilled)
    # But we must keep the register in hour hand.
    call_address_register = @addresses[root_id code.address].live_in_register(code.address)
    was_loaded = call_address_register != nil
    call_address_register ||= load code.address
    unload code.address if was_loaded
    clear read: [code.address] + code.parameters.map(&.first), written: [] of ThreeAddressCode::Address

    # Just a sanity check for testing
    if @stack.size != stack_size
      raise "Stack grew during parameter call copy !"
    end

    # We should have now zero address hosted in registers,
    # all parameters copied in stack,
    # and the call address stored in call_address_register
    # We must move the stack, then jump
    if stack_size == 0
      jalr CALL_RET_REGISTER, call_address_register
    elsif !overflow_immediate_offset? stack_size
      addi STACK_REGISTER, STACK_REGISTER, stack_size
      jalr CALL_RET_REGISTER, call_address_register
      addi STACK_REGISTER, STACK_REGISTER, -stack_size
    else
      load_immediate FILL_SPILL_REGISTER, stack_size
      add STACK_REGISTER, FILL_SPILL_REGISTER, STACK_REGISTER
      jalr CALL_RET_REGISTER, call_address_register
      load_immediate FILL_SPILL_REGISTER, -stack_size
      add STACK_REGISTER, FILL_SPILL_REGISTER, STACK_REGISTER
    end

    # Copy the return value if any
    code.into.try do |into_address|
      return_value_offset = code.return_value_offset
      raise "Unknwon function return offset" unless return_value_offset
      into = grab_for into_address
      if into_address.size == 1
        if !overflow_immediate_offset? stack_size + return_value_offset
          lw into, STACK_REGISTER, stack_size + return_value_offset
        else
          load_immediate FILL_SPILL_REGISTER, stack_size + return_value_offset
          lw into, FILL_SPILL_REGISTER, 0
        end
      else
        raise "Unsupported muti word return value move"
      end
      clear read: [] of ThreeAddressCode::Address, written: [into_address]
    end

    # PHEWWW
  end
end
