module Stacklang::ThreeAddressCode
  struct Load
    property address : Address
    property into : Address
    property ast : AST

    def initialize(@address, @into, @ast)
    end

    def to_s(io)
      @into.to_s io
      io << " = *"
      @address.to_s io
    end
  end
end
