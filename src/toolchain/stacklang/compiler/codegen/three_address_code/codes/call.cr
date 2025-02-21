module Stacklang::ThreeAddressCode
  struct Call
    property address : Address
    property into : Address?
    property return_value_offset : Int32?
    property parameters : Array({Address, Int32})
    property ast : AST

    def initialize(@address, @into, @parameters, @ast, @return_value_offset)
    end

    def to_s(io)
      @into.try do |into|
        into.to_s io
        io << " = "
      end
      @address.to_s io
      io << '('
      io << @parameters.join ", "
      io << ')'
    end
  end
end
