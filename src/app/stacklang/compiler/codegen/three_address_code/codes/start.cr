module Stacklang::ThreeAddressCode
  struct Start
    property address : Address
    property ast : AST

    def initialize(@address, @ast)
    end

    def to_s(io)
      @address.to_s io
      io << " = Return address"
    end
  end
end
