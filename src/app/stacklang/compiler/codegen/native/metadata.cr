# Metadata for three address codes addresses
# using during native code generation to control stack allocation, register hosting, and
# behavior of addresses.
class Stacklang::Native::Generator::Metadata
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

  # Spillable set when spillable Yes addresses are written.
  # If not set, spill is a no-op 
  property tainted : Bool = false

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
