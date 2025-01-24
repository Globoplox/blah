# Translate AST to three address code.
# This does handle type checks.
module Stacklang::ThreeAddressCode
  struct Anonymous
    property uid : Int32
    property size : Int32

    # Offset to the base of the real address of the uid.
    # This is used exclusively when this value is computed from
    # another local value (such as accessing a struct field)
    # In all other case it is zero.
    property offset : Int32 = 0

    def initialize(@uid, @size, @offset = 0)
    end

    def to_s(io)
      io << "_t#{@uid}"
    end
  end

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

  struct Local
    property uid : Int32 # unique name of the variable
    property size : Int32 # Size

    # Offset to the base of the real address of the uid.
    # This is used exclusively when this value is computed from
    # another local value (such as accessing a struct field)
    # In all other case it is zero.
    property offset : Int32 = 0
    
    # For locals that might be externally read/written per abi.
    # This ensure they behave as expected.
    # This may be used for function parameters and return values. 
    property abi_expected_stack_offset : Int32?

    property restricted : Bool

    property ast : AST
    
    def initialize(@uid, @offset, @size, @ast, @abi_expected_stack_offset = nil, @restricted = false)
    end

    def to_s(io)
      io << "Local(#{@uid}#{"+0x#{@offset.to_s base: 16, precision: 4}" if offset != 0})"
    end
  end

  struct Global
    property name : String
    property ast : AST?
    property size : Int32

    # Offset to the base of the real address of the uid.
    # This is used exclusively when this value is computed from
    # another local value (such as accessing a struct field)
    # In all other case it is zero.
    property offset : Int32 = 0

    def initialize(@name, @size, @ast, @offset = 0)
    end

    def to_s(io)
      io << "global(#{@name}#{"+0x#{@offset.to_s base: 16, precision: 4}" if offset != 0})"
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

  struct Load
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

  struct Store
    property address : Address
    property value : Address
    property ast : AST

    def initialize(@address, @value, @ast)
    end

    def to_s(io)
      io << "*"
      @address.to_s io
      io << " = "
      @value.to_s io
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

  alias Code = Add | Nand | Reference | Move | Call | Return | Start | Load | Store | Label | JumpEq
end
