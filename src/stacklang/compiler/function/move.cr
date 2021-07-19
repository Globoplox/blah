# TODO: handle copy with index in a temporary register with a beq loop ?
class Stacklang::Function

  # This is the big one.
  # Move a bunch of memory from a source to a destination.
  # It handle a wide range of case:
  # - If the source value is in a register
  # - If the source value is found at an address represented by an offset relative to an address in a register 
  # - If the source value is a variable that is cached in a register
  # - If the source value is found at an address represented by an offset relative to a address in a variable
  # - If the destination is a register
  # - If the destination address is represented by an offset relative to an address in a register
  # - If the destination address is represented by an offset relative to an address in a variable
  # - If the destination is a variable that is or could be cached in a register
  # All variable cache optimisation where a variable memory destination is not really written to
  # thanks to caching within register can be disabled by setting *force_to_memory* to true.
  # That should be usefull only when storing a var because it's cache register is needed for something else.
  def move(memory : Memory | Registers, constraint : Type::Any, into : Memory | Registers, force_to_memory = false)
    # If the source is a memory location holding a variable that is already cached into a register, then use this register directly.
    memory = memory.within_var.try(&.register) || memory if memory.is_a? Memory

    # If the source is a memory location relative to an address stored into a variable, we need to get that address into a register.
    memory.reference_register.as?(Variable).try do |address_variable|
      # If the var containing that address is cached in a register, just use the cache.
      if (address_register = address_variable.register)
        memory.reference_register = address_register
      else # Extract it out of cache
        memory.reference_register = cache address_variable, excludes: into.used_registers
      end
    end if memory.is_a? Memory

    # If the destination is a memory location relative to an address stored into a variable, we need to get that address into a register.
    # In this case, 
    into.reference_register.as?(Variable).try do |address_variable|
      # If the var containing that address is cached in a register, just use the cache.
      if (address_register = address_variable.register)
        into.reference_register = address_register
      else # Extract it out of cache
        into.reference_register = cache address_variable, excludes: memory.used_registers
      end
    end if into.is_a? Memory
    
    case {memory, into}
    when {Registers, Registers}
      add into, memory, Registers::R0 unless into == memory

    when {Registers, Memory}
      if force_to_memory == false && (var = into.within_var) && var.constraint.size == 1
        var.register = memory
      else
        sw memory, into.reference_register!, into.value
      end

    when {Memory, Registers}
      error "Illegal move of multiple word into register" if constraint.size > 1
      lw into, memory.reference_register!, memory.value

    when {Memory, Memory}
      if force_to_memory == false &&  (var = into.within_var) && var.constraint.size == 1
        target_register = var.register || grab_register excludes: [memory.reference_register!]
        lw target_register,  memory.reference_register!,  memory.value
        var.register = target_register

      else
        # TODO: if force_to_memory is false and we find out both location are the same, no need to compile anything.
        # TODO: check that we won't overflow max immediate
        tmp_register = grab_register excludes: [into.reference_register!, memory.reference_register!]
        (0...(constraint.size)).each do |index|
          lw tmp_register, memory.reference_register!, memory.value + index
          sw tmp_register, into.reference_register!, into.value + index
        end
        
      end
    end
  end
  
end
