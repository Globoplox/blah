module Stacklang
  abstract class Type::Any
    abstract def size

    # Solve the constraint of a struct field and map it to the right type.
    def self.solve_constraint(ast : AST::Type, types : Hash(String, Type::Struct), stack : Array(Type::Any) = [] of Type::Any) : Type::Any
      case ast
      when AST::Word then Type::Word.new
      
      when AST::Pointer
        if (target = ast.target).is_a? AST::Custom
          actual_type = types[target.name]?
          unless actual_type
            raise Exception.new "Unknown type name: '#{target.name}'", ast: ast
          end
          Type::Pointer.new actual_type
        else
          Type::Pointer.new solve_constraint target, types
        end

      when AST::Table
        if (target = ast.target).is_a? AST::Custom
          actual_type = types[target.name]?
          unless actual_type
            raise Exception.new "Unknown type name: '#{target.name}'", ast: ast
          end
          # solve the type as its size is necessary
          Type::Table.new(actual_type, ast.size.number).tap do |resolved|
            actual_type.solve types, stack + [actual_type, resolved]          
          end
        else
          Type::Table.new (solve_constraint target, types), ast.size.number
        end

      when AST::Custom
        actual_type = types[ast.name]? || raise Exception.new "Unknown type name: '#{ast.name}'", ast: ast

        if actual_type.in? stack
          message = String.build do |io|
            io << "Encountered a recursive type:\n"
            io << "Type #{actual_type}\n"
            stack.reverse.each do |parent_type|
              io << "  used in type #{parent_type}\n"
              break if parent_type == actual_type
            end
            io << "Recursive values are not allowed."
          end
          raise Exception.new message, ast: ast 
        end

        actual_type.solve types, stack + [actual_type]
        actual_type
      else raise InternalError.new "Unknown type category: #{typeof(ast)}"
      end
    end
  end

  class Type::Word < Type::Any
    getter size = 1u16

    def self.new
      @@i ||= new _init: true
    end

    def initialize(_init)
    end

    def to_s(io)
      io << "_"
    end
  end

  class Type::Pointer < Type::Any
    getter size = 1u16
    getter pointer_of

    def initialize(@pointer_of : Type::Any)
    end

    def to_s(io)
      io << '*'
      @pointer_of.to_s io
    end

    def ==(other : Type::Any)
      other.is_a?(Pointer) && other.pointer_of == @pointer_of
    end
  end

  class Type::Table < Type::Any
    getter quantity
    getter table_of

    def size
      @quantity * @table_of.size
    end

    def initialize(@table_of : Type::Any, @quantity : Int32)
    end

    def to_s(io)
      io << '['
      io << @quantity
      io << ']'
      @table_of.to_s io
    end

    def ==(other : Type::Any)
      other.is_a?(Table) && other.table_of == @table_of && other.quantity == @quantity
    end
  end

  class Type::Struct < Type::Any
    class Field
      property name
      property offset
      property constraint

      def initialize(@name : String, @constraint : Type::Any, @offset : UInt16)
      end
    end

    property name : String
    property fields : Array(Field)
    @size : UInt16? = nil
    getter ast

    def initialize(@ast : AST::Struct)
      @name = @ast.name
      @fields = [] of Field
    end

    def to_s(io)
      io << @name
    end

    def size : UInt16
      @size || raise InternalError.new "Size of type #{@name} required before it is known"
    end

    # Compute the size and fields of the structures. It needs all other structure types to be given.
    def solve(other_types : Hash(String, Type::Struct), stack : Array(Type::Any) = [] of Type::Any)
      @size ||= begin
        offset = 0u16
        @fields = @ast.fields.map do |ast_field|
          constraint = Type::Any.solve_constraint ast_field.constraint, other_types, stack # self is already added to the stack
          field = Field.new ast_field.name.name, constraint, offset
          offset += constraint.size
          field
        end
        offset
      end
    end
  end
end
