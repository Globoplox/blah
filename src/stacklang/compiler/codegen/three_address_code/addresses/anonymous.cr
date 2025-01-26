module Stacklang::ThreeAddressCode
  # Address type for anonymous temporary values
  struct Anonymous
    property uid : Int32
    property size : Int32

    # Offset to the base of the real address of the uid.
    # This is used exclusively when this value is computed from
    # another local value (such as accessing a struct field)
    # In all other case it is zero.
    property offset : Int32 = 0

    def initialize(@uid, @size, @offset = 0)
    end

    def to_s(io)
      io << "_t#{@uid}"
    end
  end
end
