
module Stacklang::ThreeAddressCode
 
  # Address type for literal values (as words or labels to be linked)
  struct Immediate
    property value : Int32 | String
    property ast : AST
    property size : Int32 = 1

    def initialize(@value, @ast)
    end

    def to_s(io)
      val = @value
      case val
      in String then val
      in Int32
        io << "0x"
        io << val.to_s base: 16, precision: 4
      end
    end
  end
end