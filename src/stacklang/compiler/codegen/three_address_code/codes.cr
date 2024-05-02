# Translate AST to three address code.
# This does handle type checks.
module Stacklang::ThreeAddressCode
  struct Literal
    property value : Int32
    property ast : AST

    def initialize(@value, @ast)
    end

    def to_s(io)
      io << "0x"
      io << @value.to_s base: 16
    end
  end

  struct Anonymous
    property value : Int32

    def initialize(@value)
    end

    def to_s(io)
      io << "_t#{@value}"
    end
  end

  struct Identifier
    property name : String
    property ast : AST

    def initialize(@name, @ast)
    end

    def to_s(io)
      io << @name
    end
  end

  alias Address = Literal | Identifier | Anonymous

  struct IfeqGoto # ???
    property var : Address
    property to : Address
    property ast : AST

    def initialize(@var, @to, @ast)
    end
  end

  struct Goto # ???
    property to : Address
    property ast : AST

    def initialize(@to, @ast)
    end
  end

  struct Assign # into = address
    property address : Address
    property into : Address
    property ast : AST

    def initialize(@address, @into, @ast)
    end
  end

  struct Add # into = left + right
    property left : Address
    property right : Address
    property into : Address
    property ast : AST

    def initialize(@left, @right, @into, @ast)
    end

    def to_s(io)
      @into.to_s io
      io << " = "
      @left.to_s io
      io << " + "
      @right.to_s io
    end
  end

  struct Nand # into = left !& right
    property left : Address
    property right : Address
    property into : Address
    property ast : AST

    def initialize(@left, @right, @into, @ast)
    end
  end

  struct DereferenceRight # into = *address
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

  struct DereferenceLeft # *into = address
    property address : Address
    property into : Address
    property ast : AST

    def initialize(@address, @into, @ast)
    end

    def to_s(io)
      io << '*'
      @into.to_s io
      io << " = "
      @address.to_s io
    end
  end

  struct Reference # into = &address
    property address : Address
    property into : Address
    property ast : AST

    def initialize(@address, @into, @ast)
    end

    def to_s(io)
      @into.to_s io
      io << " = &"
      @address.to_s io
    end
  end

  struct Call # call
    property parameters : Array(Address)
    property into : Address?
    property name : String
    property ast : AST

    def initialize(@name, @parameters, @into, @ast)
    end

    def to_s(io)
      if @into
        @into.to_s io
        io << " = "
      end
      io << @name
      io << '('
      io << @parameters.map(&.to_s).join ", "
      io << ')'
    end
  end

  struct Return # return
    property address : Address?
    property ast : AST

    def initialize(@address, @ast)
    end
  end

  alias Code = IfeqGoto | Return | Call | DereferenceLeft | DereferenceRight | Reference | Assign | Goto | Add | Nand
end
