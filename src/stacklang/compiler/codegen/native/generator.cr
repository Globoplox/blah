require "../three_address_code"
require "./assembly"



# TODO: nice errors
# TODO: creating immediate address hosting global / function address, so they can be hosted in registers 
# TODO: Full rewrite the redoc
# TODO: Parametrizable ABI (stack and call_ret register) ?
module Stacklang::Native

  # TODO: global initialization
  def self.generate_global_section(globals) : RiSC16::Object::Section
    section = RiSC16::Object::Section.new "globals"
    code = [] of RiSC16::Word
    globals.each do |global|
      section.definitions[global.symbol] = RiSC16::Object::Section::Symbol.new code.size, true
      global.typeinfo.size.times do
        code << 0u16
      end
      section.text = Slice.new code.size do |i|
        code[i]
      end
    end
    section
  end

  def self.generate_function_section(function : Function, codes : Array(ThreeAddressCode::Code)) : RiSC16::Object::Section
    Generator.new(function, codes).generate
  end

  class Generator  
    enum Register : UInt16
      R0 = 0u16
      R1 = 1u16
      R2 = 2u16 
      R3 = 3u16 
      R4 = 4u16 
      R5 = 5u16
      R6 = 6u16
      R7 = 7u16
    end

    # Hold the stack pointer
    STACK_REGISTER = Register::R7

    # Zero register, always read as 0, write discarded
    ZERO_REGISTER = Register::R0

    # Per convention, register used for storing return address on function calls
    CALL_RET_REGISTER = Register::R6

    # If all GPR registers are hosting a address that cannot be easely spilled
    # (global, further than 0x40)
    # Then it is now impossible to spill any of them without destroying another
    # There are many way to avoid this, the simplest one being
    # keeping a register that must never exclusiveley (as, not in ram) host an address.
    # We use this register for this purpose
    FILL_SPILL_REGISTER = Register::R5

    # All General Purpose Registers that can be used to store addresses values.
    # Note that it does includes the CALL_RET_REGISTER
    GPR = Register.values - [ZERO_REGISTER, STACK_REGISTER, FILL_SPILL_REGISTER]

    # Represents the stack at any time.
    # Item are added to the stack when they are used the first time
    # Item are removed from the stack when they are used the last time.
    struct Stack
      alias Index = Int32
      @slots = [] of {ThreeAddressCode::Address | Int32, Int32} # {address | free size, real stack offset}

      def to_s(io)
        @slots.each_with_index do |(entry, offset), index|
          case entry
          in ThreeAddressCode::Address then io.puts "Slot #{index}: #{entry} (real stack offset: #{offset})"
          in Int32 then io.puts "Slot #{index}: FREE (real stack offset: #{offset})"
          end
        end
      end
      
      def size
        return 0 if @slots.empty?
        (@slots.size - 1).downto(0) do |ri|
          entry, offset = @slots[ri]
          case entry
            in ThreeAddressCode::Address then return offset + entry.size
            in Int32 then next
          end
        end
        return 0
      end

      # Legacy stuff, TODO remove it and its usage
      def offset_at(index : Index) : Int32
        #@slots[index][1]
        index
      end

      def allocate(address : ThreeAddressCode::Address) : Index
        enforced = address.as?(ThreeAddressCode::Local).try &.abi_expected_stack_offset
        if enforced
          # At end of current stack ?
          offset = size

          pp "STACK SIZE: #{offset} ENFORCED ADDRESS: #{enforced}"

          if offset == enforced
            @slots << {address, offset}
            return offset
          elsif offset < enforced
            @slots << {enforced - offset, offset}
            @slots << {address, enforced}
            return enforced
          end

          # Within current stack 
          @slots.each_with_index do |(entry, offset), index|
            case entry
            in ThreeAddressCode::Address then next
            in Int32
              if offset == enforced && entry == address.size
                @slots[index] = {address, offset}
                return enforced
              elsif offset == enforced && entry > address.size
                @slots[index, 1] = [{address, offset}, {entry - address.size, offset + address.size}]
                return enforced
              elsif offset < enforced && entry == enforced - offset + address.size
                @slots[index, 1] = [{enforced - offset, offset}, {address, enforced}]
                return enforced
              elsif offset < enforced && entry > enforced - offset + address.size 
                @slots[index, 1] = [{enforced - offset, offset}, {address, enforced}, {entry -(address.size - enforced - offset), enforced + address.size}]
                return enforced
              elsif offset > enforced
                 raise "Cannot allocate #{address} at enforced stack offset #{enforced}, offset is not free" 
              end
            end
          end
          raise "Cannot allocate #{address} at enforced stack offset #{enforced}, offset is not free"
      
        else
          @slots.each_with_index do |(entry, offset), index|
            case entry
            in ThreeAddressCode::Address then next
            in Int32
              if entry == address.size
                @slots[index] = {address, offset}
                return offset
              elsif entry > address.size
                @slots[index, 1] = [{address, offset}, {entry - address.size, offset + address.size}]
                return offset
              else next
              end
            end
          end
  
          offset = size
          @slots << {address, offset}
          offset
        end
      end

      def free(index : Index)
        # Scan to find the right block
        given_offset = index
        index = nil
        @slots.each_with_index do |(entry, offset), i|
          if offset == given_offset
            index = i
            break
          end
        end
        unless index
          raise "Could not find a stack block with index #{index}"
        end

        current = @slots[index]
        start = index
        count = 1
        total_size = current.size
        base_address = current[1]

        before = @slots[index - 1]?.try do |entry, base|
          entry.as?(Int32).try do |free_size|
            count += 1
            base_address = base
            start = index - 1
            total_size += free_size
          end
        end

        @slots[index + 1]?.try do |entry, base|
          entry.as?(Int32).try do |free_size|
            count += 1
            total_size += free_size
          end
        end

        @slots[start...(start + count)] = [{total_size.as(ThreeAddressCode::Address | Int32), base_address}]
      end
    end

    class Metadata

      enum Spillable
        Always
        Yes
        Never
      end

      # If the address is currently in a register:
      # If it is a hash, denote that their are several different offset within this values that may be 
      property offsets : Hash(Int32, Register) = {} of Int32 => Register

      def live_in_register(for address) : Register?
        if address.as?(ThreeAddressCode::Immediate).try(&.value.== 0)
          return ZERO_REGISTER
        end

        case address
        when ThreeAddressCode::Anonymous, ThreeAddressCode::Local, ThreeAddressCode::Global
          @offsets[address.offset]?
        else
          @offsets[0]?
        end
      end

      def set_live_in_register(for address, register : Register?) 
        case address
        when ThreeAddressCode::Anonymous, ThreeAddressCode::Local, ThreeAddressCode::Global
          if register
            @offsets[address.offset] = register
          else
            @offsets.delete address.offset
          end
        else
          if register
            @offsets[0] = register
          else
            @offsets.delete 0
          end
        end
      end
      
      # If the address is stored in the stack:
      property spilled_at : Stack::Index?

      # Address codes indexes, used to determine when an address is not used anymore
      property used_at : Array(Int32)

      # Determine if this address can, must or must not be cached in a register or written to 
      # the stack.
      property spillable : Spillable

      def initialize(address : ThreeAddressCode::Address, first_found_at)
        @used_at = [first_found_at]
        case address
        in ThreeAddressCode::Anonymous
          @spillable = Spillable::Yes
          # Unless optimized to be reused, they will pretty much never
          # be reused. 
          # However they may be assigned once, then read once but much later.
          # Common subexpression that dont read globals/aliased nodes/call return values
          # could be made reusable by optimizer as logn as the var they read
          # are not reassigned between usage. 

        in ThreeAddressCode::Local
          if address.restricted
            @spillable = Spillable::Always
          else
            @spillable = Spillable::Yes
          end

        in ThreeAddressCode::Global
          # Never put in cache (and so never read from cache)
          # It is loaded everytime it is read
          @spillable = Spillable::Always

        in ThreeAddressCode::Function
          # Function address: can be cached, but never spilled.
          # However since it will usually be used to call after being loaded
          # which will spill/uncache. 
          @spillable = Spillable::Never
          
        in ThreeAddressCode::Immediate
          # It can be cached, but it is never spilled, and it is reloaded fully 
          # if reused and not cached. 
          @spillable = Spillable::Never
        end
      end
    end

    # List the address referenced by a code.
    def addresses_of(code : ThreeAddressCode::Code)
      case code
      in ThreeAddressCode::Add then {code.left, code.right, code.into}
      in ThreeAddressCode::Nand then {code.left, code.right, code.into}
      in ThreeAddressCode::Reference then {code.address, code.into}
      in ThreeAddressCode::Move then {code.address, code.into}
      in ThreeAddressCode::Call then code.parameters.map(&.first) + [code.address, code.into].compact
      in ThreeAddressCode::Start then {code.address}
      in ThreeAddressCode::Return then {code.address}
      in ThreeAddressCode::Store then {code.address, code.value}
      in ThreeAddressCode::Load then {code.address, code.into}
      in ThreeAddressCode::Label then Array(ThreeAddressCode::Address).new
      in ThreeAddressCode::JumpEq then code.operands.try(&.to_a) || [] of ThreeAddressCode::Address
      end
    end

    # Load ADDRESS, not values.
    def load_raw_address(address : ThreeAddressCode::Address, into : Register)
      case address
      in ThreeAddressCode::Local
        # If no stack address yet, give it one.
        # Note that the address will be valid but extra step may be required before reading/writing at the required address
        # as "address" may be cached. If so, Reading wont read the right value and Writing may be overwritten with previous value.
        meta = @addresses[root_id address]
        pp "Address #{address} address must be known but it does not have a stack index"
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

    def load(address : ThreeAddressCode::Address, avoid : Indedxable(Register)? = nil) : Register
      pp "LOAD #{address}"
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
      pp "UNLOAD #{address}"
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
            pp "Address #{address} must be spilled but does not have a stack index"
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
      pp "GRAB FREE"
      pick_in = GPR
      pick_in -= avoid if avoid
      best_pick = nil
      best_distance = 0
      pick_in.map do |register|
        took_for = @registers[register]?
        
        # There is a free register
        return register unless took_for

        # Else find the one which is the less likely to be used soon
        pp "GRAB FREE TOOK FOR #{took_for}"
        pp "ALL USED: #{@registers.values.compact.map(&.to_s).join "," }"
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
      pp "GRAB FOR #{address}"
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
      
      pp "CLEAR: #{addresses.map(&.[0]).join ", "}"

      addresses.each do |(address, written)|
        id = root_id address
        meta = @addresses[id]?
        next unless meta # Happen if the address has already been cleared, like if it is read twice

        # If it has been wrote and must be spilled, spill it
        if written && meta.spillable.always?
          pp "#{address} MUST ALWAYS BE SPILLED"
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
          pp "NO MORE REFERENCE TO #{address}"

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
      pp "RESTRICTING #{address}"
      meta = @addresses[root_id address]
      return if meta.spillable.always?
      meta.spillable = Metadata::Spillable::Always
      unload_all_offset address
    end

    def compile_move(code : ThreeAddressCode::Move)
      source_meta = @addresses[root_id code.address]
      into_meta =  @addresses[root_id code.into]

      if into_meta.spillable.never?
        raise "Cannot move to unspillable address #{code.into}, not a valid LValue"
      end

      if code.address.size != code.into.size
        raise "Size mismatch in allocation #{code}"
      elsif code.into.size == 1
        # Load address
        right = load code.address

        # If source is spillable never or spillable always, it is safe to steal the cache 
        # because it wont be used and will be deleted anyway
        # If source is spillable yes but will not be used after this, it is safe to steal the cache 

        # If source is spillable never it's safe to steal the cache, but this may be detrimental if the value is reused
        # in which case, it's better to take a new register and let future grab_free decide on which is best to unload
        if source_meta.spillable.always? || source_meta.used_at.max <= @index    
          source_meta.set_live_in_register for: code.address, register: nil
          into_meta.set_live_in_register for: code.into, register: right
          @registers[right] = code.into
        # Standard way, grab and copy
        else
          into = grab_for code.into
          add into, right, ZERO_REGISTER
        end

        clear({code.address}, {code.into})
      else 
        # TODO
        raise "Multi word move is unsupported yet"
      end
    end

    def compile_load(code : ThreeAddressCode::Load)
      if code.address.size != code.into.size
        raise "Size mismatch in load #{code}"
      elsif code.into.size == 1
        address = load code.address
        into = grab_for code.into
        lw into, address, 0
        clear(read: {code.address}, written: {code.into})
      else
        # TODO
        # must get the address of into, so intead of grab_for into, we use fill spill and put the address in it (fail for Immediate address)
        raise "Multi word load is unsupported yet"
      end
    end

    def compile_store(code : ThreeAddressCode::Store)
      if code.address.size != code.value.size
        raise "Size mismatch in store #{code}"
      elsif code.value.size == 1
        address = load code.address
        value = load code.value
        sw value, address, 0
        clear(read: {code.address, code.value}, written: Tuple().new)
      else 
        # TODO
        raise "Multi word store is unsupported yet"
      end
    end

    def compile_add(code : ThreeAddressCode::Add)
      raise "Bad operand size for value in add: #{code}" if code.into.size > 1 || code.left.size > 1 || code.right.size > 1
      left = load code.left
      right = load code.right
      into = grab_for code.into
      add into, left, right
      clear(read: {code.left, code.right}, written: {code.into})
    end

    def compile_nand(code : ThreeAddressCode::Nand)
      raise "Bad operand size for value in nand: #{code}" if code.into.size > 1 || code.left.size > 1 || code.right.size > 1
      left = load code.left
      right = load code.right
      into = grab_for code.into
      nand into, left, right
      clear(read: {code.left, code.right}, written: {code.into})
    end

    def compile_call(code : ThreeAddressCode::Call)
      # Must fix the stack size before copying all parameters
      # this mean all parameters and the call address must have a stack location (if they are spilled or not does not matter yet)
      # so load/unload operation during copy dont change the stack size
      param_registers = [] of Register
      (code.parameters.map(&.first) + [code.address]).each do |address|
        meta = @addresses[root_id address]
        if meta.spillable.yes? || meta.spillable.always?
          meta.live_in_register(address).try { |register| param_registers << register }
          stack_allocate address
        end
      end

      # We must unload everything else (same reason, ensure stack do not change size)
      unload_all GPR - param_registers

      stack_size = @stack.size

      pp "PREPARING CALL, current stack size: #{stack_size}"
      puts @stack

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
      call_address_register =  @addresses[root_id code.address].live_in_register(code.address)
      was_loaded = call_address_register != nil
      call_address_register ||= load code.address
      unload code.address if was_loaded
      clear read: [code.address] + code.parameters.map(&.first), written: [] of ThreeAddressCode::Address

      # Just a sanity check for testing
      if @stack.size != stack_size
        raise "Stack grew during parameter call copy !"
      end

      pp "CAAAAAAAAAAAAAAAAAAAAAAAAAAAALLLLLLLLLLLL"
      pp "The STACK: (size: #{stack_size})"
      puts @stack

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

    def compile_ref(code : ThreeAddressCode::Reference)
      raise "Bad operand size for value in ref: #{code}" if code.into.size > 1
      into = grab_for code.into
      load_raw_address code.address, into
      # If we took the address of a local variable, consider that it is unsafe to keep cache of it
      # or of any of it fields as their memory location might now be accessed in other ways.
      if local = code.address.as?(ThreeAddressCode::Local)
        restrict local
      end
      clear(read: Tuple().new, written: {code.into})
    end
    
    def compile_start(code : ThreeAddressCode::Start)
      meta = @addresses[root_id code.address]
      meta.set_live_in_register for: code.address, register: CALL_RET_REGISTER
      @registers[CALL_RET_REGISTER] = code.address
      clear read: [] of ThreeAddressCode::Address, written: [code.address]
    end

    def compile_return(code : ThreeAddressCode::Return)
      meta = @addresses[root_id code.address]
      jump_address_register = load code.address
      jalr ZERO_REGISTER, jump_address_register
    end

    def compile_label(code : ThreeAddressCode::Label)
      if @section.definitions.has_key? code.name
        raise "Duplicate label declaration #{code.name} is declared at 0x#{@section.definitions[code.name].address.to_s base: 16} and 0x#{@text.size.to_s base: 16}"
      end 

      # Must unload ALL because we cant garantee that the value cached will be the same when something jump here.
      # We must have no cache before creating the label, and before jumping to it so we can ensure
      # everytime we reach this label (normally or through jump), the state is the same.
      unload_all

      @section.definitions[code.name] = RiSC16::Object::Section::Symbol.new @text.size, false
    end

    # HOW TO jump 
# TAC: if t1 == t2 goto n
# ALSO: need a LABEL tac
# with t1 & t2 being optionnal.
#
# If t are set and n is short: simple beq t1 t2 n
# if t are set and n is long: 
#   fill_spill = nand t2 t2 
#   beq t1 fill_spill 1
#   jalr n
# (if t1 != t2 it will skip the jump, aka, it reach the jalr jump only if t1 == t2)
# without t1 t1: if short, beq r0 r0 n, else jalr n
#
# In any way, it must spill all, keep cache of t1, t2 and n if already set, load them if they are not and unload all
# So there is nothing improperly cached but we dont have to spill/load t1 t2 n useless (same behavior as call, but without the fixed stack constraint)
# Must add a new addres type for label OR make immediate allow symbols

    def compile_jump_eq(code : ThreeAddressCode::JumpEq)
      # TODO maybe ignore this and just make a pass on compiled text
      # is_short = !overflow_immediate_offset?(@section.definitions[code.location]?.try(&.address)) || false

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
    
      # Now, if they wern't loaded, we load them because we actually NEED them
      left_register ||= operands.try { |operands| load operands[0] }
      right_register ||= operands.try { |operands| load operands[1] }
      
      # LOAD THE LABEL (name in code.location)
      load_immediate FILL_SPILL_REGISTER, code.location

      if left_register && right_register

       
        beq left_register, right_register, 1 # If equal, jump (goto jalr)
        beq ZERO_REGISTER, ZERO_REGISTER, 1 # Else, do not jump (skip jalr)
        jalr ZERO_REGISTER, FILL_SPILL_REGISTER

      else
        jalr ZERO_REGISTER, FILL_SPILL_REGISTER
      end
    end

    def compile_code(code : ThreeAddressCode::Code)
      case code
      in ThreeAddressCode::Add then compile_add code
      in ThreeAddressCode::Nand then compile_nand code
      in ThreeAddressCode::Load then compile_load code
      in ThreeAddressCode::Store then compile_store code
      in ThreeAddressCode::Reference then compile_ref code
      in ThreeAddressCode::Move then compile_move code
      in ThreeAddressCode::Call then compile_call code
      in ThreeAddressCode::Return then compile_return code
      in ThreeAddressCode::Start then compile_start code
      in ThreeAddressCode::Label then compile_label code
      in ThreeAddressCode::JumpEq then compile_jump_eq code
      end
    end

    def generate : RiSC16::Object::Section
      @codes.each_with_index do |code, index|
        @index  = index
        compile_code code
      end

      @section.text = Slice(UInt16).new @text.to_unsafe, @text.size

      @section
    end

    @stack : Stack
    @registers : Hash(Register, ThreeAddressCode::Address?)

    # Helper func that ensure state is coherent
    def stack_allocate(address)

      pp "ALLOCATING ON STACK #{address}"

      meta = @addresses[root_id address]
      raise "Already on stack: #{address} #{meta}" if meta.spilled_at
      meta.spilled_at = @stack.allocate address

      pp "ALLOCATED AT #{meta.spilled_at}"
    end

    # Helper func that ensure state is coherent
    def stack_free(address)
      pp "FREEING #{address} FROM STACK"

      meta = @addresses[root_id address]
      raise "Already free #{address} #{meta}" unless meta.spilled_at
      meta.spilled_at.try do |index|      
        @stack.free index
      end
      meta.spilled_at = nil
    end

    # Address metadata holding, among other things, a stack location if any is needed, 
    # and potential register hosting value for some offsets of this location 
    @addresses : Hash(AddressRootId, Metadata) = {} of AddressRootId => Metadata
  
    alias AddressRootId = Int32 | String

    # Produce an root id to hash the addresses
    def root_id(address : ThreeAddressCode::Address) : AddressRootId
      case address
      in ThreeAddressCode::Anonymous
        0b00 << 30 | address.uid        
      in ThreeAddressCode::Local
        0b01 << 30 | address.uid        
      in ThreeAddressCode::Global
        address.name
      in ThreeAddressCode::Immediate 
        val = address.value
        case val
          in String then val
          in Int32 then 0b10 << 30 | val
        end
      in ThreeAddressCode::Function  
        address.name
      end
    end
    
    @codes : Array(ThreeAddressCode::Code)
    def initialize(@function : Function, @codes)
      @index = 0
      @section = RiSC16::Object::Section.new @function.symbol, options: RiSC16::Object::Section::Options::Weak
      @section.definitions[@function.symbol] = RiSC16::Object::Section::Symbol.new 0, true
      @text = [] of UInt16
      puts @function.name
      @codes.each do |code|
        puts "#{code}"
      end
      puts

      # Reverse index of registers to address
      @registers = {} of Register => ThreeAddressCode::Address?
      # Stack state
      @stack = Stack.new

      # All local addresses
      reserved_addresses = [] of ThreeAddressCode::Local

      labels = [] of String
      last_ref_to_label = {} of String => Int32
      address_used_after_label_index = {} of AddressRootId => Int32

      # Scann whole program to register addresses and compute last usage location (taking jump into account)
      # If a variable is used AFTER a label is declared, then it must stay alive (in stack) until the LAST jump to this label
      # to avoid their stack block from being freed, reused and overwritten before a jump back happen
      # (they always have a stack address before and it is spilled when reaching a label so no need to pre-allocate)
      @codes.each_with_index do |code, index|
        # Stack existing labels
        if code.is_a?(ThreeAddressCode::Label)
          labels << code.name
        end

        addresses_of(code).each do |address|
          # Note where the last jump to a label happen
          code.as?(ThreeAddressCode::JumpEq).try do |jump|
            last_ref_to_label[jump.location] = index
          end

          id = root_id address

          metadata = @addresses[id]?
          if metadata
            metadata.used_at << index
          else
            metadata = Metadata.new address, index
            @addresses[id] = metadata
 
            # Note the furthest labels declaration that this address is used after (only for spillable stuff)
            if !metadata.spillable.never?
              address_used_after_label_index[id] = labels.size
            end
 
            # Note abi expected address
            address.as?(ThreeAddressCode::Local).try do |address|
              reserved_addresses << address if address.abi_expected_stack_offset
            end
          end
        end
      end

      # For each variable, take the biggest of all the last of usages of the jump of the labels its used after, and add it to the used_at of the var
      address_used_after_label_index.each do |(address_id, last_labels_defined_before_usage)|
        # Each label defined before this variable last usage 
        # (AKA, all labels at which a jump may cause issues if the variable has lost it's stack offset between the label and the jump)
        furthest_jump = nil
        last_labels_defined_before_usage.downto(0) do |label_defined_before_usage|
          last_jump_to_this_label = last_ref_to_label[label_defined_before_usage]?
          next unless last_jump_to_this_label
          if furthest_jump.nil? || furthest_jump < last_jump_to_this_label
            furthest_jump = last_jump_to_this_label
          end
        end
        # This var is defined after some labels, the last jump to those labels is at furthest_jump
        # the var must keep its stack allocated address until at least furthest_jump
        # else it may be overwritten before the jump, and the code after the label will load at a location that may have been used by another var
        # because the var has been cleared due to not being used anymore (in the order of instruction in code, but not in the order of the execution)
        @addresses[address_id].used_at << furthest_jump if furthest_jump
      end

      pp "RESERVED ADDRESSES"
      reserved_addresses.each do |a|
        puts "  - #{a} (#{a.abi_expected_stack_offset})"
      end

      # Some stuff MUST be reserved on the stack immediately (if they exists):
      # return value (as it WILL be used and it is EXPECTED to be at a given place)
      # parameters (are they are actually already here, )
      reserved_addresses.sort_by(&.abi_expected_stack_offset.not_nil!).each do |reserved_local_address|
        # TODO: should use the abi_expected_stack_offset to assign a FORCED stack address
        stack_allocate reserved_local_address
      end

      # This support growing / shrinking the stack as needed and reusing stack slot
      # when variables dies/are declared late.
      # This pair nicely with scoped vars so they dont pollute the stack
    end
  end
end


#Hopefully we get to optimize a large part of the operations

#OR 
#- compile to inline move:
#t0 = &a
#t1 = &b
#t2 = SIZE
#t2 = t0 + t2
#t5 = 1
#LOOP:
#t4 = *t1
#*t0 = t4
#t0 = t0 + t5
#t1 = t1 + t5
#branch DONE if t0 eq t2
#branch LOOP
#DONE:
