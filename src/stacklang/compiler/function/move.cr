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

    # If the source is a variable that is already cached into a register, then use this register directly.
    if memory.is_a? Memory && memory.within_var && memory.within_var.not_nil!.register && memory.within_var.not_nil!.volatile
      memory = memory.within_var.try &.register || memory
    end
    
    # If the source is a memory location relative to an address stored into a variable, we need to get that address into a register.
    memory.reference_register.as?(Variable).try do |address_variable|
      memory.reference_register = cache address_variable, excludes: into.used_registers
    end if memory.is_a? Memory

    # If the destination is a memory location relative to an address stored into a variable, we need to get that address into a register.
    into.reference_register.as?(Variable).try do |address_variable|
      into.reference_register = cache address_variable, excludes: memory.used_registers
    end if into.is_a? Memory
    
    case {memory, into}
    when {Registers, Registers}
      add into, memory, Registers::R0 unless into == memory

    when {Registers, Memory}
      if force_to_memory == false && (into_var = into.within_var) && into_var.constraint.size == 1 && into_var.volatile
        if into_var.register
          add into_var.register.not_nil!, memory, Registers::R0
        elsif is_free_to_use memory 
          into_var.register = memory
        else
          sw memory, into.reference_register!, into.value
        end
      else
        sw memory, into.reference_register!, into.value
      end

    when {Memory, Registers}
      error "Illegal move of multiple word into register" if constraint.size > 1
      lw into, memory.reference_register!, memory.value

    when {Memory, Memory}
      if force_to_memory == false &&  (var = into.within_var) && var.constraint.size == 1 && var.volatile
        target_register = var.register || grab_register excludes: [memory.reference_register!]
        lw target_register,  memory.reference_register!,  memory.value
        var.register = target_register

      else
        if (constraint.size - 1) * 2 < 1 # approximate cost of other branch. Hard to compute because it might involve uncaching  
          tmp_register = grab_register excludes: [into.reference_register!, memory.reference_register!]
          (0...(constraint.size)).each do |index|
            lw tmp_register, memory.reference_register!, memory.value + index
            sw tmp_register, into.reference_register!, into.value + index
          end
        else
          left_register = grab_register excludes: [into.reference_register!, memory.reference_register!]
          addi left_register, memory.reference_register!, memory.value
          right_register = grab_register excludes: [left_register, into.reference_register!]
          addi right_register, into.reference_register!, into.value
          tmp_register = grab_register excludes: [left_register, right_register]
          index_register = grab_register excludes: [left_register, right_register, tmp_register]
          movi index_register, constraint.size.to_i32 - 1
          lw tmp_register, left_register, 0
          sw tmp_register, right_register, 0
          addi left_register, left_register, 1
          addi right_register, right_register, 1
          addi index_register, index_register, -1
          beq index_register, Registers::R0, 1
          beq Registers::R0, Registers::R0, -7
        end
        
      end
    end
  end
  
end
