module Stacklang::ThreeAddressCode

  # Address type for functions
  struct Function
    property name : String
    property ast : AST?
    property size : Int32 = 1

    def initialize(@name, @ast)
    end

    def to_s(io)
      io << "function(#{@name})"
    end
  end
end