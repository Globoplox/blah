module Stacklang::AST
  
  class Unit
    getter requirements
    getter types
    getter globals
    getter functions
    
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

    def dump(io, indent = 0)
      @requirements.each &.dump io, indent
      io << "\n"
      @types.each &.dump io, indent
      io << "\n"
      @globals.each &.dump io, indent
      io << "\n"
      @functions.each &.dump io, indent
    end
  end

  class Requirement
    getter target
    
    def initialize(@target : String) end

    def dump(io, indent = 0)
      io << "require \"#{@target}\"\n"
    end
  end
  
  abstract class Statement
    abstract def dump(io, indent = 0)
  end

  abstract class Type
    abstract def dump(io, indent = 0)
  end

  class Word < Type
    def dump(io, indent = 0)
      io << "_"
    end
  end

  class Pointer < Type
    def initialize(@target : Type) end
    getter target
    
    def dump(io, indent = 0)
      io << "*"
      @target.dump io, indent
    end
  end

  class Custom < Type
    def initialize(@name : String) end
    getter name
    
    def dump(io, indent = 0)
      io << @name
    end
end
  
  class Variable
    getter name
    getter constraint
    getter initialization
    
    def initialize(@name : Identifier, @constraint : Type, @initialization : Expression?) end

    def dump(io, indent = 0)
      indent.times { io << "  " }
      io << "var "
      @name.dump io, indent
      io << " : "
      @constraint.dump io, indent
      if @initialization
        io << " = "
        @initialization.try &.dump io, indent
      end
      io << "\n"
    end
  end

  class If < Statement
    def initialize(@condition : Expression, @body : Array(Statement)) end

    def dump(io, indent = 0)
      io << "if ("
      @condition.dump io, indent
      io << ") {\n"
      @body.each do |expression|
        (indent + 1).times { io << "  " }
        expression.dump io, indent + 1
        io << "\n"
      end
      indent.times { io << "  " }
      io << "}"
    end
  end

  class While < Statement
    def initialize(@condition : Expression, @body : Array(Statement)) end

    def dump(io, indent = 0)
      io << "while ("
      @condition.dump io, indent
      io << ") {\n"
      @body.each do |expression|
        (indent + 1).times { io << "  " }
        expression.dump io, indent + 1
        io << "\n"
      end
      indent.times { io << "  " }
      io << "}"
    end
  end

  class Return < Statement
    def initialize(@value : Expression) end

    def dump(io, indent = 0)
      io << "return "
      @value.dump io, indent
    end
  end

  class Function
    class Parameter
      def initialize(@name : Identifier, @constraint : Type) end
      getter name
      getter constraint

      def dump(io, indent = 0)
        @name.dump io, indent
        io << " : "
        @constraint.dump io, indent
      end
    end
    def initialize(@name : Identifier, @parameters : Array(Parameter), @return_type : Type, @variables : Array(Variable), @body : Array(Statement)) end

    def dump(io, indent = 0)
      io << "fun "
      @name.dump io, indent
      io << "("
      @parameters.each_with_index do |param, index|
        param.dump io, indent
        io << ", " if index < @parameters.size - 1
      end
      io << ") : "
      @return_type.dump io, indent
      io << " {\n"
      @variables.each do |var|
        (indent + 1).times { io << "  " }
        var.dump io, indent
      end
      io << "\n"
      @body.each do |expression|
        (indent + 1).times { io << "  " }
        expression.dump io, indent + 1
        io << "\n"
      end
      indent.times { io << "  " }
      io << "}\n\n"
    end
  end

  class Struct
    getter name
    getter fields
    
    class Field
      getter name
      getter constraint
      
      def initialize(@name : Identifier, @constraint : Type) end

      def dump(io, indent = 0)
        io << "  "
        @name.dump io, indent
        io << " : "
        @constraint.dump io, indent
        io << "\n"
      end
    end
    def initialize(@name : String, @fields : Array(Field)) end

    def dump(io, indent = 0)
      io << "struct #{@name} {\n"
      @fields.each &.dump io, indent
      io << "}\n\n"
    end
  end
  
  abstract class Expression < Statement
    abstract def dump(io, indent = 0)
  end

  class Literal < Expression
    def initialize(@number : Int32) end

    def dump(io, indent = 0)
      io << "0x"
      io << @number.to_s base: 16
    end
  end
    
  class Identifier < Expression
    def initialize(@name : String) end
    getter name
    
    def dump(io, indent = 0)
      io << @name
    end
  end
  
  class Call < Expression
    def initialize(@name : Identifier, @parameters : Array(Expression)) end

    def dump(io, indent = 0)
      @name.dump io, indent
      io << "("
      @parameters.each_with_index do |param, index|
        param.dump io, indent
        io << ", " if index < @parameters.size	- 1
      end
      io << ")"
    end
  end

  abstract class Operator < Expression
    abstract def dump(io, indent = 0)
  end

  class Access < Operator
    def initialize(@operand : Expression, @field : Identifier) end

    def dump(io, indent = 0)
      @operand.dump io, indent
      io << "."
      @field.dump io, indent
    end
  end

  class Unary < Operator
    def initialize(@operand : Expression, @name : String) end

    def dump(io, indent = 0)
      io << @name
      @operand.dump io, indent
    end
  end

  class Binary < Operator
    def initialize(@left : Expression, @name : String, @right : Expression) end

    def dump(io, indent = 0)
      @left.dump io, indent
      io << " #{@name} "
      @right.dump io, indent
    end
    
    def self.from_chain(left : Expression, chain : Array({String, Expression})?): Expression
      chain.reduce(left) do |left, (name, right)|
        Binary.new left, name, right
      end
    end
  end
  
end
