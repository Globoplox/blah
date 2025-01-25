module Stacklang::ThreeAddressCode

  struct Nand
    property left : Address
    property right : Address
    property into : Address
    property ast : AST

    def initialize(@left, @right, @into, @ast)
    end

    def to_s(io)
      @into.to_s io
      io << " = ~("
      @left.to_s io
      io << " & "
      @right.to_s io
      io << ")"
    end
  end
end
