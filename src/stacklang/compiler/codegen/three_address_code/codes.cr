# Translate AST to three address code.
# This does handle type checks.
module Stacklang::ThreeAddressCode
  struct Anonymous
    property uid : Int32

    def initialize(@uid)
    end

    def to_s(io)
      io << "_t#{@uid}"
    end
  end

  struct Immediate
    property value : Int32
    property into : Anonymous
    property ast : AST

    def initialize(@value, @into, @ast)
    end

    def to_s(io)
      io << @into
      io << " = "
      io << "0x"
      io << @value.to_s base: 16, precision: 4
    end
  end

  struct Local
    # Not an offset, but an index.
    # Higher index mean declared after lower index.
    # Index can be reused among several different local if they are declared in different blocks not interscting:
    # if a { var bar }
    # if b { var bar }
    property index : Int32
    property offset : Int32

    property ast : AST

    # If the address of this var is ever read, assumed that it is not safe to ever attempt to cache
    # the value in a register.
    # This value is muted during the initial three addresses code generation
    property aliased : Bool
    
    def initialize(@index, @offset, @ast)
      @aliased = false
    end

    def to_s(io)
      io << "Local(#{@index}+0x#{@offset.to_s base: 16, precision: 4}"
      io << ", aliased)" if @aliased
      io << ')'
    end
  end

  struct Global
    property name : String
    property offset : Int32
    property ast : AST?

    def initialize(@name, @offset, @ast)
    end

    def to_s(io)
      io << "global(#{@name}+0x#{@offset.to_s base: 16, precision: 4})"
    end
  end

  struct Add
    property left : Anonymous
    property right : Anonymous
    property into : Anonymous
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
    property left : Anonymous
    property right : Anonymous
    property into : Anonymous
    property ast : AST

    def initialize(@left, @right, @into, @ast)
    end
  end

  struct Load
    property address : Anonymous
    property into : Anonymous
    property ast : AST

    def initialize(@address, @into, @ast)
    end

    def to_s(io)
      @into.to_s io
      io << " = *"
      @address.to_s io
    end
  end

  struct Store
    property address : Anonymous
    property into : Anonymous
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

  struct Reference
    property address : Local | Global
    property into : Anonymous
    property ast : AST

    def initialize(@address, @into, @ast)
    end

    def to_s(io)
      @into.to_s io
      io << " = &"
      @address.to_s io
    end
  end

  alias Code = Add | Nand | Store | Load | Reference | Immediate
end
