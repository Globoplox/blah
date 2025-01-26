require "../three_address_code"
require "./assembly"

class Stacklang::Native::Generator
  def load_raw_address(address : ThreeAddressCode::Address, into : Register)
    case address
    in ThreeAddressCode::Local
      # If no stack address yet, give it one.
      # Note that the address will be valid but extra step may be required before reading/writing at the required address
      # as "address" may be cached. If so, Reading wont read the right value and Writing may be overwritten with previous value.
      meta = @addresses[root_id address]
      stack_allocate address
      stack_offset = @stack.offset_at meta.spilled_at.not_nil!
      stack_offset += address.offset
      if !overflow_immediate_offset? stack_offset
        addi into, STACK_REGISTER, stack_offset
      else
        load_immediate into, stack_offset
        add into, STACK_REGISTER, into
      end
    in ThreeAddressCode::Global
      load_immediate into, address.name, address.offset
    in ThreeAddressCode::Function
      load_immediate into, address.name
    in ThreeAddressCode::Immediate
      raise "Cannot evaluate address of immediate value #{address}"
    in ThreeAddressCode::Anonymous
      raise "Cannot evaluate address of temporary value #{address}"
    end
  end

  def load(address : ThreeAddressCode::Address, avoid : Array(Register)? = nil) : Register
    meta = @addresses[root_id address]
    register = meta.live_in_register for: address
    return register if register
    into = grab_free avoid: avoid
    case address
    in ThreeAddressCode::Local, ThreeAddressCode::Anonymous
      stack_offset = @stack.offset_at meta.spilled_at || raise "Local has not been allocated yet #{address}. This may happen when accessin uninitialized variales."
      stack_offset += address.offset
      if !overflow_immediate_offset? stack_offset
        lw into, STACK_REGISTER, stack_offset
      else
        load_immediate into, stack_offset
        add into, STACK_REGISTER, into
        lw into, into, 0
      end
    in ThreeAddressCode::Global
      load_immediate into, address.name, address.offset
      lw into, into, 0
    in ThreeAddressCode::Immediate
      load_immediate into, address.value
    in ThreeAddressCode::Function
      load_immediate into, address.name
    end

    meta.set_live_in_register for: address, register: into
    @registers[into] = address
    into
  end

  # Spill if needed/desirable
  # Clean register/var from being in use
  def unload(address)
    meta = @addresses[root_id address]
    register = meta.live_in_register for: address
    raise "Cannot unload address not cached" unless register

    case meta.spillable
    when Metadata::Spillable::Always, Metadata::Spillable::Yes
      case address
      when ThreeAddressCode::Global
        load_immediate FILL_SPILL_REGISTER, address.name, address.offset
        sw register, FILL_SPILL_REGISTER, 0
      else
        if meta.spilled_at.nil?
          stack_allocate address
        end

        meta.spilled_at.try do |spill_index|
          stack_offset = @stack.offset_at spill_index
          if address.is_a?(ThreeAddressCode::Local) || address.is_a?(ThreeAddressCode::Global) || address.is_a?(ThreeAddressCode::Anonymous)
            stack_offset += address.offset
          end

          if !overflow_immediate_offset? stack_offset
            sw register, STACK_REGISTER, stack_offset
          else
            load_immediate FILL_SPILL_REGISTER, stack_offset
            add FILL_SPILL_REGISTER, STACK_REGISTER, FILL_SPILL_REGISTER
            sw register, FILL_SPILL_REGISTER, 0
          end
        end
      end
    end

    meta.set_live_in_register for: address, register: nil
    @registers[register] = nil
  end

  def unload_all(registers = GPR)
    @registers.select(registers).each do |(register, address)|
      next unless address
      unload address
    end
  end

  # Unload all address related to a specific local variable.
  # This is usefull when there is aliasing of this variable.
  # Attempt to do so efficiently and using only the FILL_SPILL_REGISTER.
  def unload_all_offset(address : ThreeAddressCode::Local)
    meta = @addresses[root_id address]
    return if meta.offsets.empty?
    return if meta.spilled_at.nil?

    stack_offset = @stack.offset_at meta.spilled_at.not_nil!

    current_value = nil
    meta.offsets.to_a.sort_by(&.[0]).each do |(value_offset, register)|
      if !overflow_immediate_offset?(stack_offset + value_offset)
        sw register, STACK_REGISTER, stack_offset + value_offset
      else
        if current_value.nil?
          current_value = stack_offset + value_offset
          load_immediate FILL_SPILL_REGISTER, current_value
          add FILL_SPILL_REGISTER, STACK_REGISTER, FILL_SPILL_REGISTER
          sw register, FILL_SPILL_REGISTER, 0
        else
          diff = (stack_offset + value_offset) - current_value
          if !overflow_immediate_offset? diff
            sw register, FILL_SPILL_REGISTER, diff
          else
            current_value = stack_offset + value_offset
            load_immediate FILL_SPILL_REGISTER, current_value
            add FILL_SPILL_REGISTER, STACK_REGISTER, FILL_SPILL_REGISTER
            sw register, FILL_SPILL_REGISTER, 0
          end
        end
      end
      @registers[register] = nil
    end

    meta.offsets.clear
  end

  # In the non free register other than avoid,
  # find the one hosting the value that wont be used in the most time
  # unload that
  def grab_free(avoid : Array(Register)? = nil) : Register
    pick_in = GPR
    pick_in -= avoid if avoid
    best_pick = nil
    best_distance = 0
    pick_in.map do |register|
      took_for = @registers[register]?

      # There is a free register
      return register unless took_for

      # Else find the one which is the less likely to be used soon
      meta = @addresses[root_id took_for]
      next_usage = meta.used_at.select { |index| index >= @index }.min
      distance = next_usage - @index
      if distance > best_distance
        best_distance = distance
        best_pick = took_for
      end
    end

    if best_distance == 0 || best_pick == nil
      raise "Couldnt find any value to spill to free a register"
    end

    # Compiler is dumb about best_pick, idk why

    best_meta = @addresses[root_id best_pick.not_nil!]
    spilled_register = best_meta.live_in_register(for: best_pick) || raise "Mismatch between register and address"
    unload best_pick.not_nil!
    spilled_register
  end

  # Usefull when grabbing a register for a destination:
  # no need to load the value, but the register can be used anyway
  def grab_for(address, avoid : Array(Register)? = nil)
    meta = @addresses[root_id address]
    register = meta.live_in_register for: address
    return register if register
    register = grab_free avoid: avoid
    meta.set_live_in_register for: address, register: register
    @registers[register] = address
    return register
  end

  def clear(read, written)
    addresses = written.map { |a| {a, true} } + read.map { |a| {a, false} }

    addresses.each do |(address, written)|
      id = root_id address
      meta = @addresses[id]?
      next unless meta # Happen if the address has already been cleared, like if it is read twice

      # If it has been wrote and must be spilled, spill it
      if written && meta.spillable.always?
        # spill if it must
        unload address

        # If it always must be spilled, but has not been written, register cache is invalidated
        # (enforce re-load at every read)
      elsif meta.spillable.always?
        meta.live_in_register(for: address).try do |register|
          @registers[register] = nil
          meta.set_live_in_register for: address, register: nil
        end
      end

      # Any loaded address that wont be used anymore can be uncached, removed from stack
      if meta.used_at.max <= @index
        # free from stack
        # But NOT if it is an ABI location, as to avoid it from being overwritten
        # they are allocated at function start and stay so for the whole function
        unless address.as?(ThreeAddressCode::Local).try &.abi_expected_stack_offset
          meta.spilled_at.try do |spill_index|
            stack_free address
            meta.spilled_at = nil
          end
        end

        # Since the used_at is uid wide, if we can delete the id, all register hosting any offset
        # must be freed, not just the offset that triggered the clear (the last used offset)
        # free register
        meta.offsets.each do |(_, register)|
          @registers[register] = nil
        end
        meta.offsets.clear # just in case

        # Remove from the addresses list
        @addresses.delete id
      end
    end
  end

  # Make an address restricted.
  def restrict(address : ThreeAddressCode::Local)
    meta = @addresses[root_id address]
    return if meta.spillable.always?
    meta.spillable = Metadata::Spillable::Always
    unload_all_offset address
  end
end
