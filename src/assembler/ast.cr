require "../parsing/primitive"

module RiSC16::Assembler::AST
  alias Node = Parser::Node

  abstract class Parameter < Node
  end

  class Text < Parameter
    property text : String

    def initialize(@text)
    end
  end

  class Register < Parameter
    property index : Int32

    def initialize(@index)
    end
  end

  class Immediate < Parameter
    property offset : Int32
    property symbol : String?

    def initialize(@offset, @symbol)
    end
  end

  class Instruction < Node
    property memo : String
    property parameters : Array(Parameter)

    def initialize(@memo, @parameters)
    end
  end

  class Statement < Node
    property section : Section?
    property exported : Bool
    property symbol : String?
    property instruction : Instruction?

    def initialize(@section, @symbol, @instruction, @exported)
    end

    def empty?
      !(@section || @symbol || @instruction)
    end
  end

  class Section < Node
    property name : String
    property offset : Int32?
    property weak : Bool

    def initialize(@name, @offset = nil, @weak = false)
    end
  end

  class Unit < Node
    property name : String?
    property statements : Array(Statement)
    getter name

    def initialize(@statements, @name = nil)
    end
  end
end
