require "./tokenizer"
require "./ast"

# TODO: 
# - Structure declaration
# - Function variables
# - Statements: if, while
# - Expression: cast
# - Array access and affectation operator
class Stacklang::Parser
  alias Token = Tokenizer::Token
  
  # rule def statement_if
  #   next unless str "if"
  #   whitespace
  #   next unless char '('
  #   multiline_whitespace
  #   next unless condition = expression
  #   multiline_whitespace
  #   next unless char ')'
  #   multiline_whitespace
  #   statements : Array(Statement) = if char '{'
  #     expression_separators
  #     _statements = zero_or_more ->any_statement, separated_by: ->expression_separators
  #     expression_separators
  #     next unless char '}'
  #     _statements
  #   else
  #     next unless stat = any_statement
  #     [stat]
  #   end
  #   If.new condition, statements
  # end

  # rule def statement_while
  #   next unless str "while"
  #   whitespace
  #   next unless char '('
  #   multiline_whitespace
  #   next unless condition = expression
  #   multiline_whitespace
  #   next unless char ')'
  #   multiline_whitespace
  #   statements = if char '{'
  #                  expression_separators
  #                  _statements = zero_or_more ->any_statement, separated_by: ->expression_separators
  #                  expression_separators
  #                  next unless char '}'
  #                  _statements
  #                else
  #                  next unless stat = any_statement
  #                  [stat]
  #                end
  #   While.new condition, statements
  # end

  # rule def cast
  #   next unless char '('
  #   whitespace
  #   next unless constraint = type_constraint false, true
  #   whitespace
  #   next unless char ')'
  #   whitespace
  #   next unless target = expression
  #   Cast.new constraint, target
  # end

  # rule def variable
  #   restricted = str "restricted"
  #   next unless whitespace if restricted
  #   next unless str "var"
  #   next unless whitespace
  #   next unless name = identifier
  #   whitespace
  #   next unless constraint = type_constraint
  #   whitespace
  #   char '='
  #   whitespace
  #   init = expression
  #   Variable.new name, constraint, init, restricted: restricted != nil
  # end

  # rule def struct_field
  #   next unless name = identifier
  #   whitespace
  #   next unless constraint = type_constraint
  #   Struct::Field.new name, constraint
  # end

  # rule def struct_def
  #   next unless str "struct"
  #   next unless whitespace
  #   next unless name = type_name
  #   multiline_whitespace
  #   next unless char '{'
  #   expression_separators
  #   next unless fields = one_or_more ->struct_field, separated_by: ->expression_separators
  #   expression_separators
  #   next unless char '}'
  #   Struct.new name, fields
  # end

  enum Arity
    Unary
    Binary
  end

  @[Flags]
  enum Category
    Operand
    UnaryOperator
    BinaryOperator
  end

  alias Component = AST::Expression | {kind: Arity, value: Tokenizer::Token}
  

  # Consume greedely all tokens of a single expression.
  # Stop when it reach a ')',  '}', ','.
  # It parse leaf expression as ast node, but keep operators as is in the order they appear.
  # Return an array of all the component of the expression in their original order,
  #  mixing ast node and tuples in the form {kind: Symbol, value: Token} for operators.
  def expression_lexer : Array(AST::Expression | {kind: Arity, value: Tokenizer::Token})
    chain = [] of Component
    allows = Category::UnaryOperator | Category::Operand
    expect_more = false
    loop do
      break if current.try &.value.in? [")", "}", ","]
      token = next_token! "Any expression"
      case token.value
      
      when "("
        raise syntax_error allows.to_s unless allows.operand? 
        chain << expression
        consume! ")"
        allows = Category::BinaryOperator
        expect_more = false
      
      when "~", "!"
        raise syntax_error allows.to_s unless allows.unary_operator? 
        chain << {kind: Arity::Unary, value: token}
        allows = Category::UnaryOperator | Category::Operand
        expect_more = true
      
      when "<", ">", "=", ">=", "<=", "==", "/", "%", "|", "^", "&&", "||", "+", ".", "+=", "-=", "&=", "|=", "^=", "*=", "/=", "%="
        raise syntax_error allows.to_s unless allows.binary_operator? 
        chain << {kind: Arity::Binary, value: token}
        allows = Category::UnaryOperator | Category::Operand
        expect_more = true        
      
      when "-", "*", "&" # Ambiguous ones, determined on context
        if allows.unary_operator?
          chain << {kind: Arity::Unary, value: token}
        elsif allows.binary_operator?
          chain << {kind: Arity::Binary, value: token}
        end
        allows = Category::UnaryOperator | Category::Operand
        expect_more = true
      
      when NEWLINE
        if expect_more
          next
        else
          break
        end
      
      else
        raise syntax_error allows.to_s unless allows.includes? :operand
        if token.value.starts_with? '"'
          raise "Quoted string literal are not supported"
        elsif token.value.chars.first.ascii_number?
          chain << number token
        else
          if consume? "("
            if token.value == "sizeof"
              chain << AST::Sizeof.new token, type_constraint colon: false, explicit: true, context_token: token
              consume! ")"
            else
              call_parameters = [] of AST::Expression
              loop do
                call_parameters << expression
                case next_token!("A ',' or a ')'").value
                when "," then next
                when ")" then break
                else raise syntax_error "A ',' or a ')'"
                end
              end unless consume? ")"
              chain << AST::Call.new token, AST::Identifier.new(token, token.value), call_parameters
            end
          else
            chain << identifier token
          end
        end
        allows = Category::BinaryOperator
        expect_more = false
      end

    end
    raise syntax_error allows.to_s if expect_more
    chain
  end

  enum Associativity
    Left
    Right
  end

  # List of operator groups ordered by decreasing precedence.
  # Mostly following crystal lang 
  OPERATORS_PRIORITIES = [
    {Arity::Unary, nil, ["!", "~", "&", "*", "-"]},
    {Arity::Binary, Associativity::Left, ["."]},
    {Arity::Binary, Associativity::Left, ["/", "*"]},
    {Arity::Binary, Associativity::Left, ["+", "-"]},
    {Arity::Binary, Associativity::Left, [">>", "<<"]},
    {Arity::Binary, Associativity::Left, ["&"]},
    {Arity::Binary, Associativity::Left, ["|", "^"]},
    {Arity::Binary, Associativity::Left, ["==", "!="]},
    {Arity::Binary, Associativity::Left, ["<", ">", ">=", "<="]},
    {Arity::Binary, Associativity::Left, ["&&"]},
    {Arity::Binary, Associativity::Left, ["||"]},
    {Arity::Binary, Associativity::Right, ["=", "+=", "-="]},
  ]

  # Take a chain of `Expression` ast nodes and unprocessed operators (as the output of `#expression_lexer`)
  # and solve the operator precedence and associativity to produce one single `Expression` ast node.
  def expression_parser(chain : Array(AST::Expression | {kind: Arity, value: Tokenizer::Token})) : AST::Expression
    OPERATORS_PRIORITIES.each do |kind, associativity, operators|
      # Loop until we dont find any operator of this precedence
      loop do
        case kind
        in Arity::Binary
          index = case associativity
          in Associativity::Left, nil
            # Search for the operator, but looks starting at the end
            chain.index do |component| 
              component.is_a?({kind: Arity, value: Token}) && 
                component[:kind] == kind && 
                component[:value].value.in? operators 
            end
          in Associativity::Right
            # Search for the operator, but looks starting at the end
            chain.reverse.index do |component| 
              component.is_a?({kind: Arity, value: Token}) && 
              component[:kind] == kind && 
              component[:value].value.in? operators 
            end.try do |reversed_index|
              chain.size - 1 - reversed_index
            end
          end
          if index
            # Replace the component by an ast node.
            token = chain[index].as({kind: Arity, value: Token})[:value]
            a = chain[index - 1].as AST::Expression
            b = chain[index + 1].as AST::Expression

            if token.value == "."
              b = b.as?(AST::Identifier) || raise syntax_error "Right side of access operator must be an identifier", context: b.token
              node = AST::Access.new token, operand: a, field: b
            else
              node = AST::Binary.new token, name: token.value, left: a, right: b
            end
            chain[index -1, 3] = [node]
          else
            break
          end
        in Arity::Unary
          index = chain.reverse.index do |component| 
            component.is_a?({kind: Arity, value: Token}) && 
            component[:kind] == kind && 
            component[:value].value.in? operators 
          end.try do |reversed_index|
            chain.size - 1 - reversed_index
          end
          if index
            token = chain[index].as({kind: Arity, value: Token})[:value]
            a = chain[index + 1].as AST::Expression
            node = AST::Unary.new token, name: token.value, operand: a
            chain[index, 2] = [node]
          else 
            break
          end
        end
      end
    end

    raise "Clutter found in expression #{chain}" unless chain.size == 1
    return chain.first.as?(AST::Expression) || raise "Unknown operators in expression #{chain}"
  end

  def expression
    chain = expression_lexer
    ast = expression_parser chain
    return ast
  end
  
  def statement
    token = current
    if consume? "return"
      if consume? NEWLINE
        AST::Return.new token, nil
      else
        AST::Return.new token, expression
      end
    elsif consume? "if"
      # TODO
      AST::Identifier.new  token, "placeholder-if"
    elsif consume? "while"
      # TODO
      AST::Identifier.new token, "placeholder-while"
    else
      expression
    end
  end

  # Parse and return an identifier.
  # If an identifier is given as a parameter, it use it instead of consuming a token.
  def identifier(token = nil)
    token ||= next_token! "identifier"
    raise syntax_error "identifier" unless token.value.chars.all? do |c|
      c == '_' || c.lowercase?
    end
    AST::Identifier.new token, token.value
  end

  # Try to parse and return a type name.
  # If a type name is given as a parameter,  it use it instead of consuming a token.
  # If it fail, it return nil and does not alter the state.
  def type_name?(token = nil)
    save = @index
    token ||= next_token! "A type name"
    unless token.value.chars.first.uppercase? && token.value.chars.all? { |c| c == '_' || c.alphanumeric? }
      @index = save
      return
    end
    token 
  end

  # parse and return a type name.
  # If a type name is given as a parameter, it use it instead of consuming a token.
  def type_name(token = nil)
    type_name?(token) || raise syntax_error "type_name"
  end
    
  def number(token = nil)
    token ||= next_token! "number"
    AST::Literal.new token, token.value.to_i whitespace: false, underscore: true, prefix: true, strict: true, leading_zero_is_octal: false
  rescue ex
    raise syntax_error "number literal"
  end

  def literal(token = nil)
    number token
  end

  # Context token is used to document syntax error in case a type AST node is generated implicitely 
  def type_constraint(context_token : Token, colon = true, explicit = false)
    if colon
      unless consume? ":"
        if explicit
          raise syntax_error ":"
        else
          return AST::Word.new context_token
        end
      end
    end

    save = @index
    token = next_token! "type_specifier"

    case token.value 
    when "*"  then return AST::Pointer.new token, type_constraint colon: false, context_token: token
    when "[" then
      size = literal
      consume! "]"
      return AST::Table.new token, type_constraint(colon: false, context_token: token), size 
    when "_" then return AST::Word.new token
    else
      # Either a type name, or _ if explicit == false
      custom_name = type_name? token
      return AST::Custom.new token, custom_name.value if custom_name
      @index = save # The token was not meant for this, rollbacking.
      # TODO do it better
      return AST::Word.new context_token unless explicit
      raise syntax_error "custom_type_name"
    end
  end

  # Parse and return a function.
  def function
    root = consume! "fun"
    extern = consume? "extern"
    name = identifier
    parameters = [] of AST::Function::Parameter

    if consume? "("
    
      first = true
      had_separator = false
      loop do
        token = next_token! "A function parameter declaration or ')'"
        if token.value == ")"
          break
        elsif token.value == ","
          had_separator = true
          next
        else
          raise syntax_error ", or )" if !first && !had_separator
          param_name = identifier token
          param_constraint = type_constraint context_token: token
          parameters << AST::Function::Parameter.new token, param_name, param_constraint
          first = false
          had_separator = false
        end 
      end
      ret_type = type_constraint colon: true, explicit: true, context_token: root
    elsif consume? ":"
      ret_type = type_constraint colon: false, explicit: true, context_token: root
    else
      ret_type = nil
    end
    
    variables = [] of AST::Variable
    statements = [] of AST::Statement

    unless extern
      consume? NEWLINE
      consume! "{"
      consume? NEWLINE
      loop do
        break if consume? "}"
        next if consume? NEWLINE
        token = current
        case token.try &.value
        when "var"
          # TODO
        else
          statements << statement
        end
      end
    end

    AST::Function.new root, name, parameters, ret_type, variables, statements, extern: extern
  end

  def global
    root = consume! "var"
    extern = consume? "extern"
    name = identifier
    constraint = type_constraint colon: true, explicit: false, context_token: root
    AST::Variable.new root, name, constraint, nil, extern: extern != nil
  end

  def requirement
    root = consume! "require"
    token = next_token! "A quoted string literal"
    unless token.value.starts_with?('"') && token.value.ends_with?('"')
      raise syntax_error "A quoted string literal"
    end
    AST::Requirement.new root, token.value.strip '"'
  end

  def unit
    elements = [] of AST::Requirement | AST::Function | AST::Variable | AST::Struct
    loop do
      next if consume? NEWLINE
      case current.try &.value
      when "require" then elements << requirement
      when "var" then elements << global
      when "fun" then elements << function
      #when "struct" then
      when nil then break
      else
        raise syntax_error "require or var or fun or struct"
      end
    end
    consume? NEWLINE
    raise syntax_error "End Of File" unless eof?
    AST::Unit.from_top_level elements
  end

  NEWLINE = "\n"

  # Consume a token and raise if it not equal to *expected*.
  # Return the token.
  def consume!(expected) : Token
    token = (@tokens[@index]? || raise syntax_error expected).tap do 
      @index += 1
    end

    unless token.value == expected
      @index -= 1
      raise syntax_error expected.dump 
    end

    token
  end

  # Raise an error stating that the current token is unexpected.
  # The *expected* parameter is used to document the error.
  def syntax_error(expected, context = nil) : Exception
    token = context || @tokens[@index]?
    value = token.try(&.value) || "End Of File"
    line = token.try(&.line) || @tokens[-1].line
    character = token.try(&.character) || @tokens[-1].character
    Exception.new <<-STR
    In #{@filename} line #{line} character #{character}:
    Unexpected token #{value.dump}
    Expected: #{expected}
    STR
  end

  # Return true and consume the current token value if it is equal to *token* parameter.
  # return false otherwise.
  def consume?(token)
    if @tokens[@index]?.try(&.value) == token
      @index += 1
      return true
    else
      return false
    end
  end

  # Return the current token
  def current
    @tokens[@index]?
  end

  # True if End Of File is reached.
  def eof?
    @index >= @tokens.size
  end

  # Get the next token value. Raise if none. 
  # Parameter *expected* is used to document the raised error.
  def next_token!(expected) : Token
    (@tokens[@index]? || raise syntax_error expected).tap do 
      @index += 1
    end
  end

  @filename : String?
  def initialize(io : IO, @filename = nil)
    @tokens = Tokenizer.tokenize io, @filename
    @index = 0
  end

  def self.open(path)
    File.open path do |io| 
      new io, path
    end
  end
end