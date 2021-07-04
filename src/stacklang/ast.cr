module Stacklang::AST
  
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

    def dump(io)
      @requirements.each &.dump io
      @types.each &.dump io
      @globals.each &.dump io
      @functions.each &.dump io
    end
  end

  class Requirement
    def initialize(@target : String) end

    def dump(io)
      io << "require \"#{@target}\"\n"
    end
  end
  
  abstract class Statement
    abstract def dump(io)
  end

  abstract class Type
    abstract def dump(io)
  end

  class Word < Type
    def dump(io)
    end
  end

  class Pointer < Type
    def initialize(@target : Type) end

    def dump(io)
      io << "*"
      @target.dump io
    end
  end

  class Custom < Type
    def initialize(@name : String) end

    def dump(io)
      io << @name
    end
end
  
  class Variable
    def initialize(@name : Identifier, @constraint : Type, @initialization : Expression?) end

    def dump(io)
      io << "var "
      @name.dump io
      io << " : "
      @constraint.dump io
      io << " = "
      @initialization.try &.dump io
      io << "\n"
    end
  end

  class If < Statement
    def initialize(@condition : Expression, @body : Array(Statement)) end

    def dump(io)
      io << "if ("
      @condition.dump io
      io << ") {\n"
      @body.each do |expression|
        expression.dump io
        io << "\n"
      end
      io << "}\n"
    end
  end

  class While < Statement
    def initialize(@condition : Expression, @body : Array(Statement)) end

    def dump(io)
      io << "while ("
      @condition.dump io
      io << ") {\n"
       @body.each do |expression|
        expression.dump io
        io << "\n"
      end
      io << "}\n"
    end
  end

  class Return < Statement
    def initialize(@value : Expression) end

    def dump(io)
      io << "return "
      @value.dump io
      io << "\n"
    end
  end

  class Function
    class Parameter
      def initialize(@name : Identifier, @constraint : Type) end

      def dump(io)
        @name.dump io
        io << " : "
        @constraint.dump io
      end
    end
    def initialize(@name : Identifier, @parameters : Array(Parameter), @return_type : Type, @variables : Array(Variable), @body : Array(Statement)) end

    def dump(io)
      io << "fun "
      @name.dump io
      io << "("
      @parameters.each do |param|
        param.dump io
        io << ", "
      end
      io << ") : "
      @return_type.dump io
      io << "{\n"
      @variables.each &.dump io
      @body.each do |expression|
        expression.dump io
        io << "\n"
      end
      io << "}\n"
    end
  end

  class Struct
    class Field
      def initialize(@name : Identifier, @constraint : Type) end

      def dump(io)
        io << "  "
        @name.dump io
        io << " : "
        @constraint.dump io
        io << "\n"
      end
    end
    def initialize(@name : String, @fields : Array(Field)) end

    def dump(io)
      io << "struct #{@name} {\n"
      @fields.each &.dump io
      io << "}\n"
    end
  end
  
  abstract class Expression < Statement
    abstract def dump(io)
  end

  class Literal < Expression
    def initialize(@number : Int32) end

    def dump(io)
      io << "0x"
      io << @number.to_s base: 16
    end
  end
    
  class Identifier < Expression
    def initialize(@name : String) end

    def dump(io)
      io << @name
    end
  end
  
  class Call < Expression
    def initialize(@name : Identifier, @parameters : Array(Expression)) end

    def dump(io)
      @name.dump io
      io << "("
      @parameters.each do |param|
        param.dump io
        io << ", "
      end
      io << ")"
    end
  end

  abstract class Operator < Expression
    abstract def dump(io)
  end

  class Access < Operator
    def initialize(@operand : Expression, @field : Identifier) end

    def dump(io)
      @operand.dump io
      io << "."
      @field.dump io
    end
  end

  class Unary < Operator
    def initialize(@operand : Expression, @name : String) end

    def dump(io)
      io << @name
      @operand.dump io
    end
  end

  class Binary < Operator
    def initialize(@left : Expression, @name : String, @right : Expression) end

    def dump(io)
      @left.dump io
      io << " #{@name} "
      @right.dump io
    end
    
    def self.from_chain(left : Expression, chain : Array({String, Expression})?): Expression
      chain.reduce(left) do |left, (name, right)|
        Binary.new left, name, right
      end
    end
  end
  
end
