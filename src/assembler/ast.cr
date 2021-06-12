module RiSC16::Assembler::AST

  abstract class Parameter end
    
  class Register < Parameter
    @index : Int32
    def initialize(@index) end
  end

  class Immediate < Parameter
    @offset : Int32
    @symbol : String?
    def initialize(@offset, @symbol) end
  end
  
  class Instruction
    @memo : String
    @parameters : Array(Parameter)
    def initialize(@memo, @parameters) end
  end
  
  class Statement
    @section : Section?
    @symbol : String?
    @instruction : Instruction?
    def initialize(@section, @symbol, @instruction) end
    def empty?
      !(@section || @symbol || @instruction)
    end
  end
  
  class Section
    @name : String
    @offset : Int32?
    def initialize(@name, @offset = nil) end
  end
  
  class Unit
    @name : String?
    @statements : Array(Statement)
    def initialize(@statements) end
  end

end
