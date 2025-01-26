module Stacklang::ThreeAddressCode
  struct Store
    property address : Address
    property value : Address
    property ast : AST

    def initialize(@address, @value, @ast)
    end

    def to_s(io)
      io << "*"
      @address.to_s io
      io << " = "
      @value.to_s io
    end
  end
end
