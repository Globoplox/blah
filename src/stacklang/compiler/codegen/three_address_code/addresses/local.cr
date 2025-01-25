
module Stacklang::ThreeAddressCode

  # Addrress type for local variables
  struct Local
    property uid : Int32 # unique name of the variable
    property size : Int32 # Size

    # Offset to the base of the real address of the uid.
    # This is used exclusively when this value is computed from
    # another local value (such as accessing a struct field)
    # In all other case it is zero.
    property offset : Int32 = 0
    
    # For locals that might be externally read/written per abi.
    # This ensure they behave as expected.
    # This may be used for function parameters and return values. 
    property abi_expected_stack_offset : Int32?

    property restricted : Bool

    property ast : AST
    
    def initialize(@uid, @offset, @size, @ast, @abi_expected_stack_offset = nil, @restricted = false)
    end

    def to_s(io)
      io << "Local(#{@uid}#{"+0x#{@offset.to_s base: 16, precision: 4}" if offset != 0})"
    end
  end
end