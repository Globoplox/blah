require "./tokenizer"
require "./ast"

# TODO: 
# - Structure declaration
# - Statements: if, while
# - Expression: cast, sizeof
# - Update tokenizer to support multi character operators
# - Move consume functions to tokenizer
class Stacklang::Parser
  include Stacklang::AST
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

  # rule def statement_return
  #   next unless str "return"
  #   whitespace
  #   expr = expression
  #   Return.new expr
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

  # rule def call
  #   next unless name = identifier
  #   whitespace
  #   next unless char '('
  #   parameters = zero_or_more ->expression, separated_by: ->separator
  #   next unless char ')'
  #   Call.new name, parameters
  # end

  # rule def unary_operation
  #   next unless operator = str ["!", "*", "&", "-", "~"]
  #   next unless expr = leaf_expression
  #   # Has to be leaf else *foo.bar would be *(foo.bar) instead of (*foo).bar
  #   # and more importantly *foo = bar would be *(foo = bar)
  #   # So if we want to use an unary on a complex expression, wrap it with parenthesis
  #   Unary.new expr, operator
  # end

  # rule def sizeof
  #   next unless str "sizeof"
  #   whitespace
  #   next unless char '('
  #   whitespace
  #   next unless constraint = type_constraint false, true
  #   whitespace
  #   next unless char ')'
  #   Sizeof.new constraint
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

  # def leaf_expression
  #   or ->sizeof, ->cast, ->literal, ->unary_operation, ->parenthesis, ->call, ->identifier
  # end

  # rule def affectation_chain
  #   next unless name = str ["=", "-=", "+=", "&=", "~=", "|=", "<<=", ">>="]
  #   whitespace
  #   next unless right = low_priority_operation
  #   whitespace
  #   {name, right}
  # end

  # # Please note that all Binary operation are flattened and then
  # # Linked into a tree of expression with varying kind of associativity
  # # depending on the operator. See #Binary.from_chain

  # rule def affectation_operation
  #   next unless left = low_priority_operation
  #   whitespace
  #   chain = zero_or_more ->affectation_chain
  #   Binary.from_chain left, chain
  # end

  # rule def low_chain
  #   next unless name = str ["&", "|", "~&", "~|", "<<", ">>", "+", "-"]
  #   whitespace
  #   next unless right = medium_priority_operation
  #   whitespace
  #   {name, right}
  # end

  # rule def low_priority_operation
  #   next unless left = medium_priority_operation
  #   whitespace
  #   chain = zero_or_more ->low_chain
  #   Binary.from_chain left, chain
  # end

  # rule def medium_chain
  #   next unless name = str ["**", "*", "/", "%"]
  #   whitespace
  #   next unless right = high_priority_operation
  #   whitespace
  #   {name, right}
  # end

  # rule def medium_priority_operation
  #   next unless left = high_priority_operation
  #   whitespace
  #   chain = zero_or_more ->medium_chain
  #   Binary.from_chain left, chain
  # end

  # rule def high_chain
  #   next unless name = str ["<=", ">=", "==", "!=", "||", "&&", "<", ">", "^", "["]
  #   whitespace
  #   if name == "["
  #     next unless right = expression
  #     whitespace
  #     next unless char ']' if name == "["
  #   else
  #     next unless right = access
  #   end
  #   whitespace
  #   {name, right}
  # end

  # rule def high_priority_operation
  #   next unless left = access
  #   whitespace
  #   chain = zero_or_more ->high_chain
  #   Binary.from_chain left, chain
  # end

  # rule def access_chain
  #   next unless char '.'
  #   next unless id = identifier
  #   id
  # end

  # rule def access
  #   next unless expr = leaf_expression
  #   chain = zero_or_more ->access_chain
  #   chain.reduce(expr) do |expr, field|
  #     Access.new expr, field
  #   end
  # end

  # def operation
  #   affectation_operation
  # end

  # rule def number
  #   sign = str(["-", "+"]) || ""
  #   case str ["0x", "0b"]
  #   when "0x" then base = 16
  #   when "0b" then base = 2
  #   else           base = 10
  #   end
  #   next unless digits = one_or_more ->{ char ['0'..'9', 'a'..'f', 'A'..'F'] }
  #   begin
  #     Literal.new (sign + digits.join).to_i32 base: base
  #   rescue
  #     nil
  #   end
  # end

  # def literal
  #   number
  # end

  # rule def parenthesis
  #   next unless char '('
  #   multiline_whitespace
  #   expr = expression
  #   multiline_whitespace
  #   next unless char ')'
  #   expr
  # end

  # rule def expression
  #   operation
  # end

  # def any_statement : Statement?
  #   # checkpoint "any statement" do
  #   or(->statement_if, ->statement_while, ->statement_return, ->expression).as(Statement?)
  #   # end
  # end

  # rule def type_name
  #   next unless head = char 'A'..'Z'
  #   tail = zero_or_more ->{ char ['A'..'Z', 'a'..'z', '0'..'1', '_'..'_'] }
  #   return String.build do |io|
  #     io << head
  #     tail.each do |tail_char|
  #       io << tail_char
  #     end
  #   end
  # end

  # # Does not allows the same modifier as function variables
  # rule def global
  #   extern = str "extern"
  #   next unless whitespace if extern
  #   next unless str "var"
  #   next unless whitespace
  #   next unless name = identifier
  #   whitespace
  #   next unless constraint = type_constraint
  #   whitespace
  #   char '='
  #   whitespace
  #   init = expression
  #   Variable.new name, constraint, init, extern: extern != nil
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

  alias Component = Expression | {kind: Arity, value: Tokenizer::Token}
  
  # Consume greedely all tokens of a single expression.
  # Stop when it reach a ')',  '}', ','.
  # It parse leaf expression as ast node, but keep operators as is in the order they appear.
  # Return an array of all the component of the expression in their original order,
  #  mixing ast node and tuples in the form {kind: Symbol, value: Token} for operators.
  def expression_lexer : Array(Expression | {kind: Arity, value: Tokenizer::Token})
    chain = [] of Component
    allows = [:unary_operator, :operand]
    expect_more = false
    loop do
      break if peek &.in? [")", "}", ","]
      token = next_token! "Any expression"
      pp "TOKEN"
      pp token
      case token.value
      
      when "("
        unexpected! "A #{allows.map(&.to_s).join " or "}" unless allows.includes? :operand 
        chain << expression
        expect! ")"
        allows = [:binary_operator]
        expect_more = false
      
      when "~", ".", "!"
        unexpected! "A #{allows.map(&.to_s).join " or "}" unless allows.includes? :unary_operator 
        chain << {kind: Arity::Unary, value: token}
        allows = [:unary_operator, :operand]
        expect_more = true
      
      when "<", ">", "=", ">=", "<=", "==", "/", "%", "|", "^", "&&", "||", "+"
        unexpected! "A #{allows.map(&.to_s).join " or "}" unless allows.includes? :binary_operator 
        chain << {kind: Arity::Binary, value: token}
        allows = [:unary_operator, :operand]
        expect_more = true        
      
      when "-", "*", "&"
        if allows.includes? :unary_operator
          unexpected! "A #{allows.map(&.to_s).join " or "}" unless allows.includes?(:binary_operator) || allows.includes?(:unary_operator)
          chain << {kind: Arity::Unary, value: token}
        elsif allows.includes? :binary_operator
          unexpected! "A #{allows.map(&.to_s).join " or "}" unless allows.includes? :binary_operator
          chain << {kind: Arity::Binary, value: token}
        else
          # Should not happen
        end
        allows = [:unary_operator, :operand]
        expect_more = true
      
      when NEWLINE
        if expect_more
          next
        else
          break
        end
      
      else
        pp "a"
        unexpected! "A #{allows.map(&.to_s).join " or "}" unless allows.includes? :operand
        if token.value.starts_with? '"'
          raise "Quoted string literal are not supported"
        elsif token.value.starts_with? '0'
          chain << number token
        else
          pp "b"
          # if consume? # simpler
          if peek &.== "("
            next_token? # Consume it
            call_parameters = [] of Expression
            loop do
              call_parameters << expression
              case next_token!("A ',' or a ')'").value
              when "," then next
              when ")" then break
              else unexpected! "A ',' or a ')'"
              end
            end
            chain << Call.new token, Identifier.new(token, token.value), call_parameters
          else
            pp "c"
            chain << identifier token
          end
        end
        allows = [:binary_operator]
        expect_more = false
      end

    end
    unexpected! "A #{allows.map(&.to_s).join " or "}" if expect_more
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
    {Arity::Binary, Associativity::Left, ["&"]},
    {Arity::Binary, Associativity::Left, ["|", "^"]},
    {Arity::Binary, Associativity::Left, ["=="]},
    {Arity::Binary, Associativity::Left, ["<", ">", ">=", "<="]},
    {Arity::Binary, Associativity::Left, ["&&"]},
    {Arity::Binary, Associativity::Left, ["||"]},
    {Arity::Binary, Associativity::Right, ["=", "+=", "-="]},
  ]

  # Take a chain of `Expression` ast nodes and unprocessed operators (as the output of `#expression_lexer`)
  # and solve the operator precedence and associativity to produce one single `Expression` ast node.
  def expression_parser(chain : Array(Expression | {kind: Arity, value: Tokenizer::Token})) : Expression
    pp "---------"
    pp "ROUND OF EXP PARSER"
    pp "INPUT"
    pp chain
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
            a = chain[index - 1].as Expression
            b = chain[index + 1].as Expression
            node = Binary.new token, name: token.value, left: a, right: b
            chain[index -1, 3] = [node]
          else
            break
          end
        in Arity::Unary
          index = chain.index do |component| 
            component.is_a?({kind: Arity, value: Token}) && 
            component[:kind] == kind && 
            component[:value].value.in? operators 
        end
          if index
            pp "FOUND operator at index #{index}"
            pp chain
            token = chain[index].as({kind: Arity, value: Token})[:value]
            a = chain[index + 1].as Expression
            node = Unary.new token, name: token.value, operand: a
            chain[index, 2] = [node]
            pp chain
          else 
            break
          end
        end
      end
    end

    pp "OUTPUT"
    pp chain

    raise "Clutter found in expression #{chain}" unless chain.size == 1
    return chain.first.as?(Expression) || raise "Unknown operators in expression #{chain}"
  end

  def expression
    chain = expression_lexer
    pp "LEXER OUTPUT:"
    pp chain
    ast = expression_parser chain
    pp ast
    return ast
  end
  
  def statement(token)
    case token.value
    when "return"
      if consume? NEWLINE
        Return.new token, nil
      else
        Return.new token, expression
      end
    when "if"
      # TODO
      Identifier.new  token, "placeholder-if"
    when "while"
      # TODO
      Identifier.new token, "placeholder-while"
    else
      expression
    end
  end

  # Parse and return an identifier.
  # If an identifier is given as a parameter, it use it instead of consuming a token.
  def identifier(token = nil)
    token ||= next_token! "identifier"
    unexpected! "identifier" unless token.value.chars.all? do |c|
      c == '_' || c.lowercase?
    end
    Identifier.new token, token.value
  end

  # Try to parse and return a type name.
  # If a type name is given as a parameter,  it use it instead of consuming a token.
  # If it fail, it return nil and does not alter the state.
  def type_name?(token = nil)
    save = @index
    token ||= next_token?
    return unless token
    unless token.value.chars.first.uppercase? && token.value.chars.all? { |c| c == '_' || c.alphanumeric? }
      @index = save
      return
    end
    token 
  end

  # parse and return a type name.
  # If a type name is given as a parameter, it use it instead of consuming a token.
  def type_name(token = nil)
    type_name?(token) || unexpected! "type_name"
  end
    
  def number(token = nil)
    token ||= next_token! "number"
    Literal.new token, token.value.to_i whitespace: false, underscore: true, prefix: true, strict: true, leading_zero_is_octal: false
  rescue ex
    unexpected! "number literal"
  end

  def literal(token = nil)
    number token
  end

  def type_constraint(colon = true, explicit = false, context_token = nil)
    if colon
      unless consume? ":"
        if explicit
          unexpected! ":"
        else
          return Word.new context_token
        end
      end
    end

    save = @index
    token = next_token! "type_specifier"
    case token.value 
    when "*"  then return Pointer.new token, type_constraint colon: false
    when "[" then
      size = literal
      expect! "]"
      return Table.new token, type_constraint(colon: false), size 
    when "_" then return Word.new token
    else
      # Either a type name, or _ if explicit == false
      custom_name = type_name? token
      return Custom.new token, custom_name.value if custom_name
      @index = save # The token was not meant for this, rollbacking.
      # TODO do it better
      return Word.new context_token unless explicit
      unexpected! "custom_type_name"
    end
  end

  # Parse and return a function.
  def function
    root = expect! "fun"
    extern = consume? "extern"
    name = identifier
    token = next_token! "( or :"
    parameters = [] of Function::Parameter

    if token.value == "("
    
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
          unexpected! ", or )" if !first && !had_separator
          param_name = identifier token
          param_constraint = type_constraint context_token: token
          parameters << Function::Parameter.new token, param_name, param_constraint
          first = false
          had_separator = false
        end 
      end
      ret_type = type_constraint colon: true, explicit: true, context_token: root
    elsif token.value == ":"
      ret_type = type_constraint colon: false, explicit: true, context_token: root
    else
      unexpected! "( or :"
    end
    
    variables = [] of Variable
    statements = [] of Statement

    unless extern
      consume? NEWLINE
      expect! "{"
      consume? NEWLINE
      loop do
        case current.try &.value
        when "}" then break
        when "var"
          # TODO
        when NEWLINE
          # Do nothing
        else
          statements << statement token
        end
      end
    end

    Function.new root, name, parameters, ret_type, variables, statements, extern: extern
  end

  def global
    root = expect! "var"
    extern = consume? "extern"
    name = identifier
    constraint = type_constraint colon: true, explicit: false
    Variable.new root, name, constraint, nil, extern: extern != nil
  end

  def requirement
    root = expect! "require"
    token = next_token! "A quoted string literal"
    unless token.value.starts_with?('"') && token.value.ends_with?('"')
      unexpected! "A quoted string literal"
    end
    Requirement.new root, token.value.strip '"'
  end

  def unit
    elements = [] of Requirement | Function | Variable | Struct
    loop do
      consume? NEWLINE
      case current.try &.value
      when "require" then elements << requirement
      when "var" then elements << global
      when "fun" then elements << function
      #when "struct" then
      when nil then break
      else unexpected! "require or var or fun or struct"
      end
    end
    consume? NEWLINE
    unexpected! "End Of File" unless eof?
    Unit.from_top_level elements
  end

  NEWLINE = "\n"

  # Consume a token and raise if it not equal to *expected*.
  # Return the token.
  def expect!(expected) : Token
    token = (@tokens[@index]? || unexpected! expected).tap do 
      @index += 1
    end

    unexpected! expected.dump unless token.value == expected

    token
  end

  # Raise an error stating that the current token is unexpected.
  # The *expected* parameter is used to document the error.
  def unexpected!(expected) : NoReturn
    token = @tokens[@index - 1]?
    value = token.try(&.value) || "End Of File"
    line = token.try(&.line) || @tokens[-1].line
    character = token.try(&.character) || @tokens[-1].character
    raise Exception.new <<-STR
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

  # Return true if the block return true for the current token.
  # Does not consume
  def peek
    yield @tokens[@index]?.try &.value
  end

  # True if End Of File is reached.
  def eof?
    @index >= @tokens.size
  end

  # Get the next token value. Raise if none. 
  # Parameter *expected* is used to document the raised error.
  def next_token!(expected) : Token
    (@tokens[@index]? || unexpected! expected).tap do 
      @index += 1
    end
  end

   # Get the next token value if any
  def next_token? : Token?
    @tokens[@index]?.try &.tap do 
      @index += 1
    end
  end

  @filename : String?
  def initialize(io : IO, @filename = nil)
    @tokens = Tokenizer.tokenize io
    pp @tokens.map(&.value)
    @index = 0
  end
end

File.open ARGV.first do |file|
  unit = Stacklang::Parser.new(file).unit
  pp unit
  puts unit.to_s
end
