module Stacklang::ThreeAddressCode
  struct Label
    property name : String
    property ast : AST

    def initialize(@name, @ast)
    end

    def to_s(io)
      io << @name
      io << ":"
    end
  end
end
