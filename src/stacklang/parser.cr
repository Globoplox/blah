require "colorize"
require "./tokenizer"
require "./ast"

# TODO: 
# - Array access and affectation operator
class Stacklang::Parser
  alias Token = Tokenizer::Token
  
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
      
      when "<", ">", "=", ">=", "<=", "==", "/", "%", "|", "^", "&&", "||", "+", ".", ">>", "<<", 
        "+=", "-=", "&=", "|=", "^=", "*=", "/=", "%="
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
            case token.value 
            when "sizeof"
              chain << AST::Sizeof.new token, type_constraint colon: false, explicit: true, context_token: token
              consume! ")"
            when "cast"
              cast_to = type_constraint colon: false, explicit: true, context_token: token
              consume! ","
              target = expression
              chain << AST::Cast.new token, cast_to, target
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
    {Arity::Binary, Associativity::Left, ["."]},
    {Arity::Unary, nil, ["!", "~", "&", "*", "-"]},
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

    elsif (is_if = consume? "if") || (is_while = consume? "while")
      consume! "("
      cond = expression
      consume! ")"
      consume? NEWLINE
      statements = [] of AST::Statement
      if consume? "{"
        consume? NEWLINE
        loop do
          break if consume? "}"
          next if consume? NEWLINE
          statements << statement
        end
      else
        statements << statement
      end
      if is_if
        AST::If.new token, cond, statements
      else
        AST::While.new token, cond, statements
      end

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

    if name.in? ["sizeof", "cast"]
      raise syntax_error "Name '#{name.name}' is not allowed for functions"
    end

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
    
    body = [] of AST::Statement 

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
          consume? "var"
          restricted = consume? "restricted"
          var_name = identifier
          var_constraint = type_constraint colon: true, explicit: false, context_token: token.not_nil!
          init = expression if consume? "="
          body << AST::Variable.new token.not_nil!, var_name, var_constraint, init, extern: false, restricted: restricted
        else
          body << statement
        end
      end
    end

    AST::Function.new root, name, parameters, ret_type, body: body, extern: extern
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

  def structure 
    root = consume! "struct"
    name = type_name
    consume? NEWLINE
    consume! "{"
    fields = [] of AST::Struct::Field
    loop do
      consume? NEWLINE
      break if consume? "}"
      token = next_token! "A struct member name" 
      field_name = identifier token
      constraint = type_constraint explicit: false, colon: true, context_token: token
      fields << AST::Struct::Field.new token, field_name, constraint
    end
    AST::Struct.new root, name.value, fields
  end

  def unit
    elements = [] of AST::Requirement | AST::Function | AST::Variable | AST::Struct
    loop do
      next if consume? NEWLINE
      case current.try &.value
      when "require" then elements << requirement
      when "var" then elements << global
      when "fun" then elements << function
      when "struct" then elements << structure
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
      raise syntax_error expected.dump 
    end

    token
  end

  class Exception < ::Exception
  end

  # Raise an error stating that the current token is unexpected.
  # The *expected* parameter is used to document the error.
  def syntax_error(expected, context = nil) : Exception
    Exception.new String.build { |io|
    if filename = @filename
      io << "In "
      io << filename
      io << ":\n"
    end
    io << "Syntax Error"
      token = context || @tokens[@index - 1]? || @tokens[@index]?
      if token
        io << " line "
        io << token.line
        io << " column "
        io << token.character
        if (locs = @locs) && (loc = locs[token.line - 1]?) 
          io << '\n'
          io.puts "=" * 40
          [
            locs[token.line - 3]?,
            locs[token.line - 2]?
          ].compact.each do |before|
            io.puts before
          end
          loc = loc + "  "
          io.puts [loc[0, token.character - 1].colorize.bold, token.value.colorize.bold.underline, loc[(token.character - 1 + token.value.size)..].colorize.bold].join.gsub("\n", "")
          io.puts (" " * (token.character - 1)) + ("^" * token.value.size)
          [
            locs[token.line]?,
            locs[token.line + 1]?
          ].compact.each do |after|
            io.puts after
          end
          io << "=" * 40
        else 
          io << ": \""
          io << token.value.dump
          io << '"'
        end
      end
      io << '\n'
      io << "Expected: "
      io << expected
    }
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
  # Cache of all line of codes, used for fancy debug.
  @locs : Array(String)?
  def initialize(io : IO, @filename = nil, fancy = true)
    if fancy 
      @locs = io.gets_to_end.lines
      io.rewind
    end
    @tokens = Tokenizer.tokenize io, @filename
    @index = 0
  end

  def self.open(path)
    File.open path do |io| 
      new io, path
    end
  end
end