module Stacklang::ThreeAddressCode
  
  # Address type for global variables
  struct Global
    property name : String
    property ast : AST?
    property size : Int32

    # Offset to the base of the real address of the uid.
    # This is used exclusively when this value is computed from
    # another local value (such as accessing a struct field)
    # In all other case it is zero.
    property offset : Int32 = 0

    def initialize(@name, @size, @ast, @offset = 0)
    end

    def to_s(io)
      io << "global(#{@name}#{"+0x#{@offset.to_s base: 16, precision: 4}" if offset != 0})"
    end
  end
end