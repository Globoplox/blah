module RiSC16::Assembler::AST

  abstract class Parameter end
    
  class Register < Parameter
    property index : Int32
    def initialize(@index) end
  end

  class Immediate < Parameter
    property offset : Int32
    property symbol : String?
    def initialize(@offset, @symbol) end
  end
  
  class Instruction
    property memo : String
    property parameters : Array(Parameter)
    def initialize(@memo, @parameters) end
  end
  
  class Statement
    property section : Section?
    property exported : Bool
    property symbol : String?
    property instruction : Instruction?
    def initialize(@section, @symbol, @instruction, @exported) end
    def empty?
      !(@section || @symbol || @instruction)
    end
  end
  
  class Section
    property name : String
    property offset : Int32?
    def initialize(@name, @offset = nil) end
  end
  
  class Unit
    property name : String?
    property statements : Array(Statement)
    getter name
    def initialize(@statements) end
  end

end
