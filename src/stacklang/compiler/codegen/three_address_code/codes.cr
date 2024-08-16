# Translate AST to three address code.
# This does handle type checks.
module Stacklang::ThreeAddressCode
  struct Anonymous
    property uid : Int32
    property size : Int32

    def initialize(@uid, @size)
    end

    def to_s(io)
      io << "_t#{@uid}"
    end
  end

  struct Immediate
    property value : Int32
    property ast : AST
    property size : Int32 = 1

    def initialize(@value, @ast)
    end

    def to_s(io)
      io << "0x"
      io << @value.to_s base: 16, precision: 4
    end
  end

  struct Local
    property uid : Int32 # unique name
    property offset : Int32
    property size : Int32
    # Designate locals that might be externally read/written per abi.
    # This ensure they behave as expected
    property abi_expected : Bool

    property ast : AST
    
    def initialize(@uid, @offset, @size, @ast, @abi_expected = false)
      @aliased = false
    end

    def to_s(io)
      io << "Local(0x#{@offset.to_s base: 16, precision: 4})"
    end
  end

  struct Global
    property name : String
    property ast : AST?
    property size : Int32

    def initialize(@name, @size, @ast)
    end

    def to_s(io)
      io << "global(#{@name})"
    end
  end

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

  alias Address =  Anonymous | Local | Global | Immediate | Function

  ########

  struct Add
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

  struct Nand
    property left : Address
    property right : Address
    property into : Address
    property ast : AST

    def initialize(@left, @right, @into, @ast)
    end
  end

  struct Move
    property address : Address
    property into : Address
    property ast : AST

    def initialize(@address, @into, @ast)
    end

    def to_s(io)
      @into.to_s io
      io << " = "
      @address.to_s io
    end
  end

  struct Reference
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

  # Spill all (but load address if already loaded)
  # Copy parameters
  # Set load address as NOT cached (but no need to spill)
  # load address
  # Move stack
  # Jump
  # Move stack back
  # If needed, copy return value
  struct Call
    property address : Address
    property into : Address?
    property parameters : Array(Address)
    property ast : AST

    def initialize(@address, @into, @parameters, @ast)
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

  alias Code = Add | Nand | Reference | Move | Call | Return | Start
end
