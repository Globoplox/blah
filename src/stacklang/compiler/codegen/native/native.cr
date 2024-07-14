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

    enum Register
      R0 = 0
      R1 = 1
      R2 = 2 
      R3 = 3 
      R4 = 4 
      R5 = 5
      R6 = 6
    end

    GPR = [
      Register::R1, Register::R2, Register::R3,
      Register::R4, Register::R5, Register::R6
    ]

    struct Metadata

      enum Spillable
        Always
        Yes
        Never
      end

      property live_in_register : Register?
      property spilled_at : Int32?
      property used_at : Array(Int32)
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
          # Optimizer could detect that it may be reused
          # then it can be cached (and so: spillable::Yes)
          @spillable = Spillable::Always

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

    def load_raw(address : ThreeAddressCode::Address, into : Register)
      case address
      when ThreeAddressCode::Anonymous 

      when ThreeAddressCode::Local 
      
      when ThreeAddressCode::Global
        # Address 
        movi into, address.name
        offset = address.offset
          if offset > 0x3f
            addi into, into, offset
            offset = 0
        end
        # if there is an offset that is higher, need a tmp register:
      
      when ThreeAddressCode::Immediate 
        movi into, address.value

      when ThreeAddressCode::Function
        movi into, address.name
      end
    end

    # Get the value for the given address into a register
    # If necessary, call grab free
    def load(*addresses : ThreeAddressCode::Address, avoid : Array(Register)) : Indexable(Register)
      # for each address, if its loaded, put it into the avoid list
      # for each address map: 
      #   if its loaded OK
      #   grab a free
      #   put that free in avoid list
      #   raw_load it OK
    end

    # Spill if needed/desirable
    # Clean register/var from being in use
    def unload(address)
    end

    # In the non free register other than avoid, 
    # find the one hosting the value that wont be used in the most time
    # unload that
    def grab_free(avoid : Array(Register)) : Register
      
    end

    # Same as grab free, but if address is alraedy loaded in a register
    # then return this register
    def grab_free_for(address : ThreeAddressCode::Address, avoid : Array(Register)) : Register
      
    end

    def clear
      # For each temporary loaded in a register
      #  if it MUST be spilled, spill it
      # If it is not live after the current code, unload it.
    end

    def compile_add(code : Add)
      # Load addresses
      # Grab a free register 
      #   (avoid ing the one just loaded)
      #   if target is already cached in a register, use it (a = 3; a = a + 3)
      # compile the add
      # consider the into as being cached into the add register
      # clear
    end

    def compile_code(code : ThreeAddressCode::Code)
    end

    def generate : RiSC16::Object::Section
      @section.text = Slice.new @text.size do |i|
        @text[i]
      end
      @section
    end

    def initialize(@function : Function)
      @codes = ThreeAddressCode.translate @function
      puts @function.name
      @codes.each do |code|
        puts "#{code}"
      end
      puts

      # Optimize

      @addresses = [] of {ThreeAddressCode::Address, Metadata}
      @registers = {} of Register => Metadata

      @codes.each_with_index do |code, index|
        addresses_of(code).each do |address|
          metadata = @addresses.find { |it| address_eq(it[0], address) }
          if metadata
            metadata[1].used_at << index
          else
            metadata = Metadata.new address, index
            @addresses << {address, metadata}
          end
        end
      end

      @section = RiSC16::Object::Section.new @function.symbol, options: RiSC16::Object::Section::Options::Weak
      @text = [] of UInt16
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
