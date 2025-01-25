module Stacklang::ThreeAddressCode

  struct JumpEq
    property operands : {Address, Address}?
    property location : String
    property ast : AST

    def initialize(@location, @operands, @ast)
    end

    def to_s(io)
      @operands.try do |(left, right)|
        io << "if #{left} == #{right} "
      end
      io << "goto #{@location}"
    end
  end
end
