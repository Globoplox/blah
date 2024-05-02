class Stacklang::Function
  # Compile the function statements to three address codes.
  # There is no type anymore, everything is a word, even addresses.
  # The only supported operators are the one supported by the backend

  module Tac
    struct Literal
      property value : Int32
      def initialize(@value) end
    end

    struct Anonymous
      property value : Int32
      def initialize(@value) end
    end

   struct Identifier
     property name : String
     def initialize(@name) end
   end

    
    alias Address = Literal | Identifier | Anonymous

    struct IfeqGoto
      property var : Address
      property to : Address
    end

    struct Goto
      property to : Address
    end

    struct Assign # into = address
      property address : Address
      property into : Address
    end

    struct Add # into = left + right
      property left : Address
      property right : Address
      property into : Address
    end

    struct Nand # into = left !& right
      property left : Address
      property right : Address
      property into : Address
    end

    struct DerefR # into = *address
      property address : Address
      property into : Address
    end

    struct DerefL # *into = address
      property address : Address
      property into : Address
    end

    struct Call # call
      property parameters : Array(Address)
    end

    struct Return # return
      property address : Address?
    end

    alias Code = IfeqGoto | Return | Call | DerefL | DerefR | Assign | Goto | Add | Nand
  end
  
  struct Translator
    @tacs = [] of {Code, Type}
    @fun : Function
    @statements : Array(AST::Statements)
    
    def initialize(@statements : Array(AST::Statements), @fun : Function)
    end

    def translate
      @statements.each do |statement|
        translate_statement statement
      end
    end
     
    def translate_expression(expression : AST::Expression): {Address, Type}
      case expression
      in AST::Literal 
        {Literal.new expression.number, Type::Word.new}

      in AST::Sizeof 
        {Literal.new(@unit.typeinfo(expression.constraint).size.to_i32), Type::Word.new}

      in AST::Cast
        {translate_expression(expression.target), @unit.typeinfo(expression.constraint)}

      in AST::Identifier
        {}
        
      in AST::Call
      in AST::Operator
        case expresion
        in AST::Access
        in AST::Unary
        in AST::Binary
        end
      end
    end
    
    def translate_statement(statement : AST::Statement)
      case statement
      in AST::Variable
      in AST::If        
      in AST::While
      in AST::Return
      in AST::Expression
        translate_expression statement
      end      
    end

  end

end
