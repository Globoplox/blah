require "./tokenizer"

abstract class Stacklang::AST

  property token : Tokenizer::Token?
  
  def line 
    @token.try &.line || "???"
  end
  
  def character 
    @token.try &.character || "???"
  end
  
  abstract def dump(io, indent = 0)

  def to_s(io : IO)
    dump io
  end

  class Unit
    getter requirements
    getter types
    getter globals
    getter functions

    def initialize(@requirements : Array(Requirement), @types : Array(Struct), @globals : Array(Variable), @functions : Array(Function))
    end

    def self.from_top_level(top_level)
      requirements = [] of Requirement
      types = [] of Struct
      globals = [] of Variable
      functions = [] of Function
      top_level.each do |element|
        case element
        when Requirement then requirements.push element
        when Struct      then types.push element
        when Variable    then globals.push element
        when Function    then functions.push element
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

  class Requirement < AST
    getter target

    def initialize(@token, @target : String)
    end

    def dump(io, indent = 0)
      io << "require \"#{@target}\"\n"
    end
  end

  abstract class Statement < AST
  end

  abstract class Type < AST
  end

  class Word < Type
    def initialize(@token)
    end

    def dump(io, indent = 0)
      io << "_"
    end
  end

  class Pointer < Type
    getter target
    def initialize(@token, @target : Type)
    end

    def dump(io, indent = 0)
      io << "*"
      @target.dump io, indent
    end
  end

  class Table < Type
    getter target
    getter size

    def initialize(@token, @target : Type, @size : Literal)
    end

    def dump(io, indent = 0)
      @target.dump io, indent
      io << '['
      io << @size
      io << ']'
    end
  end

  class Custom < Type
    getter name

    def initialize(@token, @name : String)
    end

    def dump(io, indent = 0)
      io << @name
    end
  end

  class Variable < Statement
    getter name
    getter constraint
    getter initialization
    getter restricted
    getter extern

    def initialize(@token, @name : Identifier, @constraint : Type, @initialization : Expression?, @restricted = false, @extern = false)
    end

    def dump(io, indent = 0)
      indent.times { io << "  " }
      io << "var "
      io << "extern " if @extern
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
    getter condition
    getter body

    def initialize(@token, @condition : Expression, @body : Array(Statement))
    end

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
    getter condition
    getter body

    def initialize(@token, @condition : Expression, @body : Array(Statement))
    end

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
    getter value

    def initialize(@token, @value : Expression?)
    end

    def dump(io, indent = 0)
      io << "return "
      @value.try &.dump io, indent
    end
  end

  class Function < AST
    class Parameter < AST
      getter name
      getter constraint

      def initialize(@token, @name : Identifier, @constraint : Type)
      end

      def dump(io, indent = 0)
        @name.dump io, indent
        io << " : "
        @constraint.dump io, indent
      end
    end

    getter name
    getter parameters
    getter return_type
    getter body
    getter extern

    def initialize(@token, @name : Identifier, @parameters : Array(Parameter), @return_type : Type?, @body : Array(Statement), @extern : Bool)
    end

    def dump(io, indent = 0)
      io << "fun "
      io << "extern " if @extern
      @name.dump io, indent
      io << "("
      @parameters.each_with_index do |param, index|
        param.dump io, indent
        io << ", " if index < @parameters.size - 1
      end
      io << ") "
      io << ": " if @return_type
      @return_type.try &.dump io, indent
      unless @extern
        io << " {\n"
        @body.each do |expression|
          (indent + 1).times { io << "  " }
          expression.dump io, indent + 1
          io << "\n"
        end
        indent.times { io << "  " }
        io << "}\n\n"
      end
    end
  end

  class Struct < AST
    getter name
    getter fields

    class Field
      getter name
      getter constraint
      getter token

      def initialize(@token : Tokenizer::Token, @name : Identifier, @constraint : Type)
      end

      def dump(io, indent = 0)
        io << "  "
        @name.dump io, indent
        io << " : "
        @constraint.dump io, indent
        io << "\n"
      end
    end

    def initialize(@token, @name : String, @fields : Array(Field))
    end

    def dump(io, indent = 0)
      io << "struct #{@name} {\n"
      @fields.each &.dump io, indent
      io << "}\n\n"
    end
  end

  abstract class Expression < Statement
  end

  class Literal < Expression
    getter number

    def initialize(@token, @number : Int32)
    end

    # For codegen / syntaxic sugar. TODO: track origin
    def initialize(@number : Int32)
    end

    def dump(io, indent = 0)
      io << "0x"
      io << @number.to_s base: 16
    end
  end

  class Sizeof < Expression
    getter constraint

    def initialize(@token, @constraint : Type)
    end

    def dump(io, indent = 0)
      io << "sizeof("
      @constraint.dump io
      io << ")"
    end
  end

  class Cast < Expression
    getter constraint
    getter target

    def initialize(@token, @constraint : Type, @target : Expression)
    end

    def dump(io, indent = 0)
      io << "("
      @constraint.dump io
      io << ")"
      @target.dump io
    end
  end

  class Identifier < Expression
    getter name

    def initialize(@token, @name : String)
    end

    # For codegen / syntaxic sugar. TODO: track origin
    def initialize(@name : String)
    end

    def dump(io, indent = 0)
      io << @name
    end
  end

  class Call < Expression
    getter name
    getter parameters

    def initialize(@token, @name : Identifier, @parameters : Array(Expression))
    end

    # For codegen / syntaxic sugar. TODO: track origin
    def initialize(@name : Identifier, @parameters : Array(Expression))
    end

    def dump(io, indent = 0)
      @name.dump io, indent
      io << "("
      @parameters.each_with_index do |param, index|
        param.dump io, indent
        io << ", " if index < @parameters.size - 1
      end
      io << ")"
    end
  end

  abstract class Operator < Expression
  end

  class Access < Operator
    getter operand
    getter field

    def initialize(@token, @operand : Expression, @field : Identifier)
    end

    def dump(io, indent = 0)
      @operand.dump io, indent
      io << "."
      @field.dump io, indent
    end
  end

  class Unary < Operator
    getter operand
    getter name

    def initialize(@token, @operand : Expression, @name : String)
    end

    # For codegen / syntaxic sugar. TODO: track origin
    def initialize(@operand : Expression, @name : String)
    end


    def dump(io, indent = 0)
      io << @name
      @operand.dump io, indent
    end
  end

  class Binary < Operator
    getter name
    getter left
    getter right

    def initialize(@token, @left : Expression, @name : String, @right : Expression)
    end

    # For codegen / syntaxic sugar. TODO: track origin
    def initialize(@left : Expression, @name : String, @right : Expression)
    end

    def dump(io, indent = 0)
      @left.dump io, indent
      io << " #{@name} "
      @right.dump io, indent
    end
  end
end
