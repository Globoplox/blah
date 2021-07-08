module Stacklang
  
  abstract class Type::Any
    abstract def size

    # Solve the constraint of a struct field and map it to the right type.
    def self.solve_constraint(ast : AST::Type, types : Hash(String, Type::Struct), stack : Array(Type::Struct) = [] of Type::Struct) : Type::Any
      case ast
      when AST::Word then Type::Word.new
      when AST::Pointer
        if (target = ast.target).is_a? AST::Custom
          Type::Pointer.new types[target.name]? || raise "Pointer to unknow struct name: '#{target.name}'"
        else
          Type::Pointer.new solve_constraint target, types
        end
      when AST::Custom
        
        actual_type = types[ast.name]? || raise "Unknown struct name: '#{ast.name}'"
        raise "Type #{actual_type.name} is recursive. This is illegal. Use a pointer to #{actual_type.name} instead." if actual_type.in? stack
        actual_type.solve types, stack + [actual_type]
        actual_type
      else raise "Unknown Type Kind #{typeof(ast)}"
      end
    end
    
  end

  class Type::Word < Type::Any
    getter size = 1u16
  end

  class Type::Pointer < Type::Any
    getter size = 1u16
    def initialize(@pointer_of : Type::Any) end
  end
  
  class Type::Struct < Type::Any
    class Field
      property name
      property any
      property offset
      def initialize(@name : String, @type : Type::Any, @offset : UInt16) end
    end

    property name : String
    property fields : Array(Field)
    @size : UInt16? = nil
    
    def initialize(@ast_struct : AST::Struct)
      @name = @ast_struct.name
      @fields = [] of Field
    end

    def size : UInt16
      @size || raise "Type must be solved before size can be used"
    end

    # Compute the size and fields of the structures. It needs all other structure types to be given.
    def solve(other_types : Hash(String, Type::Struct), stack : Array(Type::Struct) = [] of Type::Struct)
      @size ||= begin
        offset = 0u16
        @fields = @ast_struct.fields.map do |ast_field|
          constraint = Type::Any.solve_constraint ast_field.constraint, other_types, stack + [self]
          Field.new ast_field.name.name, constraint, (offset += constraint.size) 
        end
        offset
      end
    end

  end

end
