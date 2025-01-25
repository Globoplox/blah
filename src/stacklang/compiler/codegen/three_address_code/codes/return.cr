module Stacklang::ThreeAddressCode

  struct Return
    property address : Address
    property ast : AST

    def initialize(@address, @ast)
    end  

    def to_s(io)
      io << "Return to "
      @address.to_s io
    end
  end
end