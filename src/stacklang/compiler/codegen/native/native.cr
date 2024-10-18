require "../three_address_code"
require "./assembly"

module Stacklang::Native
  
  def self.generate(function : Function) : RiSC16::Object::Section
    Generator.new(function).generate   
  end

  class Generator  
    # GP registers => hosted
    # Vars => Symbol OR stack offset
    # Temporaries => hosted into registers
    #                index in code of all usages (identify if they are live)
    #                (added as they appear, removed when dead)
    # 
    # Register 0 is always free
    # Temporaries hosted in register 0 are never spilled, and they have a size in stack of 0
    #                  or even actually: temporaries only have a real stack offset
    #                  when they are not being held by a register.
    #                  ALSO: reaching a temporary stack offset higher than the immediate size could raise an error/warning
    #                  ALSO: rollback the fact that all local var become *&a, and replace with a. Load / store is always instruction 
    #                    (unless stack is too high, then its more optimal to cache the address, but it would likely be too high)
    #                    but anyway it wont matter, when we assign like a[300] = 5, the lvalue is extracted.
    #                    so even if we keep a = b + 1 as t0 = 1; t1 = b; t2 = t0 + t1.... 
    # Special case for assigning literal 0 to constant temporary does that.

    # Codes can be: constant (default to false), aliased (default to true)
    # These would be figured out by optimizer. 
    # Constant is used internaly by optimizer and here also to use reg0
    # Aliased is used to avoid unexpectde behavior in optimizer and to force spilling.


    # CODES TO ADD: 
    # - function (start of function)
    # - return
    # - call & push (hum. How to handle the copy ?
    # 
    # Push: act as a literal in which the address of the param is written
    #       like: t0 = Push  (push is going to be a unique label) the actual value will be given later  
    # Call: spill all, move stack. It also define the symbol of the last PUSH value as a literal that correspond to
    # the right offset to write the parameter to the stack.
    # 
    # Why ? the objective is to have the actual stack fluctuate with currentl live/dead temporaries
    # 
    # 

    # IDEA: in object file relocation, allows ti include an offset. That on add call less in a lot of place

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

    GPR = [
      Register::R1, Register::R2, Register::R3,
      Register::R4, Register::R5, Register::R6
    ]

    # Represents the stack at any time.
    # Item are added to the stack when they are used the first time
    # Item are removed from the stack when they are used the last time.
    # They keep their position in stack while spilled.
    struct Stack
      alias Index = Int32
      @slots = [] of {ThreeAddressCode::Address | Int32, Int32}
      
      def offset_at(index : Index) : Int32
        @slots[index][1]
      end

      def allocate(address : ThreeAddressCode::Address) : Index
        @slots.each_with_index do |(entry, offset), index|
          case address
          in ThreeAddressCode::Address then next
          in Int32
            if entry == address.size
              @slots[index] = {address, offset}
              return index
            elsif entry > address.size
              @slots[index] = [{address, offset}, {entry - address.size, offset + address.size}]
              return index
            else next
            end
          end
        end

        @slots << {address, @slots.last?.try(&.[1].+(address.size)) || 0}
        @slots.size - 1
      end

      def free(index : Index)
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


    # THERE IS A THING:
    # IF ALL GPR ARE TAKEN BY ADDRESSES WHO ARE NOT EASY TO STORE/LOAD
    # (global, local further than 0x40)
    # THEN WE CANT SPILL ANYMORE.
    # This mean we must never get into this situation.
    # HOW TO: have one GPR that is always used for temporary values discared immediately. Never using cache.
    struct Metadata

      enum Spillable
        Always
        Yes
        Never
      end

      # If the address is currently in a register:
      property live_in_register : Register?

      # If the address is stored in the stack:
      property spilled_at : Stack::Index?

      # Address codes indexes, used to determine when an address is not used anymore
      # TODO: use only the max value
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
          # 
          # If it is larger than 1, it will always be spilled.
          # This is true for local, globals and immediate too
          

        in ThreeAddressCode::Local
          # Optimizer could detect that it may be aliased
          # then it can be cached (and so: spillable::Yes)
          # Some are easily cachable: return address can stay in a register
          @spillable = Spillable::Yes

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
          @live_in_register = Register::R0 if address.value == 0
        end
      end
    end

    # Compate two addresses and check if they refer to the same thing.
    def address_eq(address : ThreeAddressCode::Address, other : ThreeAddressCode::Address) : Bool
      case {address, other}
      when {ThreeAddressCode::Anonymous, ThreeAddressCode::Anonymous} 
        address.uid == other.uid
      when {ThreeAddressCode::Local, ThreeAddressCode::Local} 
        address.uid == other.uid && address.offset == other.offset
      when {ThreeAddressCode::Global, ThreeAddressCode::Global} 
        address.name == address.name
      when {ThreeAddressCode::Immediate, ThreeAddressCode::Immediate} 
        address.value == other.value
      when {ThreeAddressCode::Function, ThreeAddressCode::Function}  
        address.name == other.name
      else false
      end
    end

    # List the address referenced by a code.
    def addresses_of(code : ThreeAddressCode::Code)
      case code
      in ThreeAddressCode::Add then {code.left, code.right, code.into}
      in ThreeAddressCode::Nand then {code.left, code.right, code.into}
      in ThreeAddressCode::Reference then {code.address, code.into}
      in ThreeAddressCode::Move then {code.address, code.into}
      in ThreeAddressCode::Call then code.parameters + [code.address, code.into].compact
      in ThreeAddressCode::Start then {code.address}
      in ThreeAddressCode::Return then {code.address}
      end
    end

    # Load address without attempt at being smart.
    # Load ADDRESS, not value.
    # Used for lvalues ?
    def load_raw_address(address : ThreeAddressCode::Address, into : Register)
      raise "Cannot load wide address into register" if address.size > 1
      case address
      in ThreeAddressCode::Local, ThreeAddressCode::Anonymous
        stack_offset = @stack.offset_at @addresses[address].spilled_at || raise "Local has not been alocated yet #{address}" 
        load_immediate into, -stack_offset
        add into, Register::R7, into
      
      in ThreeAddressCode::Global
        movi into, address.name
      
      in ThreeAddressCode::Immediate
        movi into, address.value

      in ThreeAddressCode::Function
        movi into, address.name
      end
    end

    def load(address : ThreeAddressCode::Address, avoid : Indedxable(Register)? = nil) : Register
      pp "LOAD #{address}"
      meta = @addresses[address]
      register = meta.live_in_register
      return register if register
      into = grab_free avoid: avoid
      case address
      in ThreeAddressCode::Local, ThreeAddressCode::Anonymous
        stack_offset = @stack.offset_at @addresses[address].spilled_at || raise "Local has not been allocated yet #{address}" 
        if stack_offset < 0x39
          lw into, Register::R7, -stack_offset
        else
          load_immediate into, -stack_offset
          add into, Register::R7, into
          lw into, into, 0
        end
      in ThreeAddressCode::Global
        movi into, address.name
        lw into, into, 0
      in ThreeAddressCode::Immediate
        movi into, address.value
      in ThreeAddressCode::Function
        movi into, address.name
      end

      into
    end

    # Spill if needed/desirable
    # Clean register/var from being in use
    def unload(address)
      pp "UNLOAD #{address}"
      meta = @addresses[address]
      register = meta.live_in_register
      raise "Cannot unload address not cached" unless register 
      case meta.spillable
      in Metadata::Spillable::Never
        # Nothing to do, just clear the reg usage
      in Metadata::Spillable::Yes, Metadata::Spillable::Always
        #
        # 
        meta.spilled_at.try do |spill_index|
          stack_offset = @stack.offset_at spill_index
          if stack_offset < 0x39
            sw register, Register::R7, -stack_offset
          else
            # Should unload another to store the address.
            raise "Far stack spilling is not yet supported"
          end
        end || if meta.spillable.always?
          raise "Address must be spilled but does not have a stack index"
        end
      end

      meta.live_in_register = nil
      @registers[register] = nil
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
        # NEVER allow to have ALL GPR taken by HARD TO SPILL
        # (anything but local/anonymous with stack offset < 0x40)
        # So if it will happen ? Unload one more register 
        
        # There is a free register
        return register unless took_for

        # Else find the one which is the less likely to be used soon
        meta = @addresses[took_for]
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

      best_meta = @addresses[best_pick]
      spilled_register = best_meta.live_in_register || raise "Mismatch between register and address"
      unload best_pick
      spilled_register
    end

    # Usefull when grabbing a register for a destination:
    # no need to load the value, but the register can be used anywat
    #  
    def grab_for(address, avoid : Array(Register)? = nil)
      pp "GRAB FOR #{address}"
      meta = @addresses[address]
      register = meta.live_in_register
      return register if register
      grab_free avoid: avoid
    end

    def clear(*addresses)
      pp "CLEAR: #{addresses}"
      addresses.each do |address|
        meta = @addresses[address]
        if meta.used_at.max <= @index

          # free from stack
          meta.spilled_at.try do |spill_index|
            @stack.free spill_index
            meta.spilled_at = nil
          end

          # free register
          meta.live_in_register.try do |register|
            @registers[register] = nil
            meta.live_in_register = nil
          end
          
          # Remove from the addresses list
          @addresses.delete address

        elsif meta.spillable.always?
          # spill if it must
          unload address 
        end
      end
    end

    def compile_add(code : ThreeAddressCode::Add)
      pp "COMPILE ADD"
      # load a, b into registers
      # 
      # 
      # left right into
      raise "Bad operand size for value in add: #{code}" if code.into.size > 1 || code.left.size > 1 || code.right.size > 1
      into = grab_for code.into
      left = load code.left
      right = load code.right
      add into, left, right
      clear code.left, code.right, code.into
      # Load addresses
      # Grab a free register 
      #   (avoid ing the one just loaded)
      #   if target is already cached in a register, use it (a = 3; a = a + 3)
      # compile the add
      # consider the into as being cached into the add register
      # clear
    end

    def compile_start(code : ThreeAddressCode::Start)
      # Its special, it has privilegies.
      # The address should be marked as cachable as it cannot be reasonnably aliased.
      # But I did not made it possible through TAC, so I enforce it here.
      meta = @addresses[code.address]
      meta.live_in_register = Register::R6
      @registers[Register::R6] = code.address
    end

    def compile_return(code : ThreeAddressCode::Return)
      jump_address_register = load code.address
      jalr Register::R0, jump_address_register
    end

    def compile_code(code : ThreeAddressCode::Code)
      case code
      in ThreeAddressCode::Add then compile_add code
      in ThreeAddressCode::Nand then raise "Unsupported yet"
      in ThreeAddressCode::Reference then raise "Unsupported yet"
      in ThreeAddressCode::Move then raise "Unsupported yet"
      in ThreeAddressCode::Call then raise "Unsupported yet"
      in ThreeAddressCode::Return then compile_return code
      in ThreeAddressCode::Start then compile_start code
      end
    rescue ex
      pp ex
    end

    def generate : RiSC16::Object::Section
      @codes.each_with_index do |code, index|
        @index  = index
        compile_code code
      end

      pp @text
      @section.text = Slice(UInt16).new @text.to_unsafe, @text.size

      @section
    end

    @addresses : Hash(ThreeAddressCode::Address, Metadata)
    @stack : Stack
    @registers : Hash(Register, ThreeAddressCode::Address?)

    # Helper func that ensure state is coherent
    def stack_allocate(address)
      meta = @addresses[address]
      raise "Already on stack: #{address} #{meta}" if meta.spilled_at
      meta.spilled_at = @stack.allocate address
    end

    # Helper func that ensure state is coherent
    def stack_free(address)
      meta = @addresses[address]
      raise "Already free #{address} #{meta}" unless meta.spilled_at
      meta.spilled_at.try do |index|      
        @stack.free index
      end
      meta.spilled_at = nil      
    end

    def initialize(@function : Function)
      @index = 0
      @section = RiSC16::Object::Section.new @function.symbol, options: RiSC16::Object::Section::Options::Weak
      @text = [] of UInt16
      @codes = ThreeAddressCode.translate @function
      puts @function.name
      @codes.each do |code|
        puts "#{code}"
      end
      puts

      # Reverse index of registers to address
      @registers = {} of Register => ThreeAddressCode::Address?
      # Stack state
      @stack = Stack.new

      # Find all uniq addresses and assign metadata
      uniq_addresses = [] of {ThreeAddressCode::Address, Metadata}
      # All local addresses
      reserved_addresses = [] of ThreeAddressCode::Local
      @codes.each_with_index do |code, index|
        addresses_of(code).each do |address|
          metadata = uniq_addresses.find { |it| address_eq(it[0], address) }
          if metadata
            metadata[1].used_at << index
          else
            metadata = Metadata.new address, index
            uniq_addresses << {address, metadata}
            address.as?(ThreeAddressCode::Local).try do |address|
            reserved_addresses << address if address.abi_expected
            end
          end
        end
      end

      @addresses  = uniq_addresses.to_h

      # Some stuff MUST be reserved on the stack immediately (if they exists):
      # return value (as it WILL be used and it is EXPECTED to be at a given place)
      # parameters (are they are actually already here, )
      reserved_addresses.sort_by(&.offset).each do |reserved_local_address|
        stack_allocate reserved_local_address
      end

      # This support growing / shrinking the stacl as needed and reusing stack slot
      # when variables dies/are declared late.
      # This pair nicely with scoped vars so they dont pollute the stack
    end
  end
end

    # TODO how to: a = call()
    # result of call is not an lvalue ? => yes it is.
    # since the return value is written on the stack.
    # However it ver temporary.
    # Which mean if used, it must be copied right away.
    # 
    # Because when moving size>1 stuff we must ensure the tmprary are stored 
    # in a continuous and well ordered area
    # ( a = call().field  )
    # Move, Store and Load may take a size param.
    # Store and Move only difference is that:
    # a = b:
    # MOVE local(a), local(b)
    # AKA load rx, r7 + offset(b)
    #     store rx, r7 + offset(a)
    # 
    # *a = *b:
    # t0 = *(local b)
    # t1 = *(local a)
    # MOVE t1, t0 
    # AKA
    # load rx, r7 + offset(b)
    # load ry, rx
    # load rz, r7 + offset(a)
    # store ry, rz 
    # 
    # dereferencing does not exists, there is only MOVE
    # so load / store must diasppear as code an be replaced by MOVE
    # MOVE copy stuff, from: Memory at (absolute or not) to: Memory at (absolute or not) 
    # 
    # MOVE do, so: 
    # take a temporary that hold an absolute address or a Local, or a Global (a source to load from : r?, r7, lui+add)
    # and move it to a temporary.
    # 
    # The MOVE can perform the same thing as the previous version did:
    # if size is 1, and we move cachable into cachable, we can noop and just say the register is now dedicated to the new.
    #   (do it only if new is reused sooner than old )
    # 
    # Reference still exists, when we need to load an address explicitely 
    # 
    # SO: tmp, globals and other things should have a size
    # 
    # 
    # LOAD: take VALUE at ADDRESS into REG
    # - store into is an address of the place to copy to, and the copy is mandatory
    # - move into is an address of the place to copy to

      # TODO handle complex types: if size > 2, instead of right value we need lvalue and copy.
    # And then copy:
    # - compile to serie of:
#a:[2]
#b:[2]
#a = b

#t0 = &a
#t1 = &b
#t2 = *t1
#*t0 = t2
#t3 = t0 + 1
#t4 = t1 + 1
#t5 = *t4
#*t3 = t5

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
