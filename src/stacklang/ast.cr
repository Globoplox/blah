module AST
  
  class Unit
    def initialize(@requirements : Array(Requirement), @types : Array(Struct), @globals : Array(Variable), @functions : Array(Function)) end
    def self.from_top_level(top_level)
      requirements = [] of Requirement
      types = [] of Struct
      globals = [] of Variable
      functions = [] of Function
      top_level.each do |element|
        case element
        when Requirement then requirements.push element
        when Struct then types.push element
        when Variable then globals.push element
        when Function then functions.push element
        end
      end
      Unit.new requirements, types, globals, functions
    end
  end

  class Requirement
    def initialize(@target : String) end
  end
  
  abstract class Statement end

  abstract class Type end

  class Word < Type end

  class Pointer < Type
    def initialize(@target : Type) end
  end

  class Custom < Type
    def initialize(@name : String) end
  end
  
  class Variable
    def initialize(@name : Identifier, @constraint : Type, @initialization : Expression?) end
  end

  class If < Statement
    def initialize(@condition : Expression, @body : Block) end
  end

  class While < Statement
    def initialize(@condition : Expression, @body : Block) end
  end

  class Function
    class Parameter
      def initialize(@name : Identifier, @constraint : Type) end
    end
    def initialize(@name : Identifier, @parameters : Array(Parameter), @variables : Array(Variable), @body : Array(Statement)) end
  end

  class Struct
    class Field
      def initialize(@name : Identifier, @constraint : Type) end
    end
    def initialize(@name : String, @fields : Array(Field)) end
  end
  
  abstract class Expression < Statement end

  class Literal < Expression
    def initialize(@number : Int32) end
  end
    
  class Identifier < Expression
    def initialize(@name : String) end
    def to_s(io)
      io << @name
    end
  end
  
  class Call < Expression
    def initialize(@name : Identifier, @parameters : Array(Expression)) end
  end

  abstract class Operator < Expression end

  class Access < Operator
    def initialize(@operand : Expression, @field : Identifier) end
  end

  class Unary < Operator
    def initialize(@operand : Expression, @name : String) end
  end

  class Binary < Operator
    def initialize(@left : Expression, @name : String, @right : Expression) end

    def to_s(io)
      io << "(#{@left})#{@name}(#{@right})"
    end
    
    def self.from_chain(left : Expression, chain : Array({String, Expression})?): Expression
      chain.reduce(left) do |left, (name, right)|
        Binary.new left, name, right
      end
    end
  end
  
end
