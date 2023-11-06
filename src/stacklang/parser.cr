require "./lexer"
require "./ast"

class Stacklang::Parser
  include Stacklang::AST
  
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

  # rule def requirement
  #   next unless str "require"
  #   next unless whitespace
  #   next unless char '"'
  #   next unless filename = consume_until "\""
  #   next unless char '"'
  #   Requirement.new filename
  # end


  # rule def function
  #   extern = str "extern"
  #   next unless whitespace if extern
  #   next unless str "fun"
  #   @checkpoint.name = "Function"
  #   @checkpoint.locked = true
  #   next unless whitespace
  #   next unless name = identifier
  #   @checkpoint.name = "Function #{name.name}"
  #   parameters = checkpoint "parameters" do
  #     next unless char '('
  #     next unless params = one_or_more ->function_parameter, separated_by: ->separator
  #     next unless char ')'
  #     params
  #   end || [] of Function::Parameter
  #   whitespace
  #   ret_type = type_constraint explicit: true

  #   unless extern
  #     multiline_whitespace
  #     next unless char '{'
  #     expression_separators

  #     variables = zero_or_more ->variable, separated_by: ->expression_separators
  #     if variables.empty?
  #       expression_separators
  #     else
  #       next unless expression_separators
  #     end

  #     statements = zero_or_more ->any_statement, separated_by: ->expression_separators
  #     expression_separators
  #     next unless char '}'
  #   end

  #   Function.new name, parameters, ret_type, (variables || [] of Variable), (statements || [] of Statement), extern: extern != nil
  # end


  # Parse and return an identifier.
  # If an identifier is given as a parameter, it use it instead of consuming a token.
  def identifier(value = nil)
    value ||= next_token! "identifier"
    unexpected! "identifier" unless value.chars.all? do |c|
      c == '_' || c.lowercase?
    end
    Identifier.new value
  end

  # Try to parse and return a type name.
  # If a type name is given as a parameter,  it use it instead of consuming a token.
  # If it fail, it return nil and does not alter the state.
  def type_name?(value = nil)
    save = @index
    value ||= next_token?
    return unless value
    unless value.chars.first.uppercase? && value.chars.all? { |c| c == '_' || c.alphanumeric? }
      @index = save
      return
    end
    value
  end

  # parse and return a type name.
  # If a type name is given as a parameter, it use it instead of consuming a token.
  def type_name(value = nil)
    type_name?(value) || unexpected! "type_name"
  end
    
  def number(value = nil)
    value ||= next_token! "number"
    Literal.new value.to_i whitespace: false, underscore: true, prefix: true, strict: true, leading_zero_is_octal: false
  rescue ex
    unexpected! "number literal"
  end

  def literal(value = nil)
    number value
  end

  def type_constraint(colon = true, explicit = false)
    if colon
      unless consume? ":"
        if explicit
          unexpected! ":"
        else
          return Word.new
        end
      end
    end

    save = @index
    case token = next_token! "type_specifier"
    when "*"  then return Pointer.new type_constraint colon: false
    when "[" then
      size = literal
      expect! "]"
      return Table.new type_constraint(colon: false), size 
    when "_" then return Word.new
    else
      # Either a type name, or _ if explicit == false
      custom_name = type_name? token
      return Custom.new custom_name if custom_name
      @index = save # The token was not meant for this, rollbacking.
      return Word.new unless explicit
      unexpected! "custom_type_name"
    end
  end

  # Parse and return a function, assuming "fun" keyword has already been consumed.
  def function
    extern = consume? "extern"
    name = identifier
    token = next_token! "( or :"
    parameters = [] of Function::Parameter

    if token  == "("
    
      first = true
      had_separator = false
      loop do
        token = next_token?
        if token == ")" 
          break
        elsif token == ","
          had_separator = true
          next
        else
          unexpected! ", or )" if !first && !had_separator
          param_name = identifier token
          param_constraint = type_constraint
          parameters << Function::Parameter.new param_name, param_constraint
          first = false
          had_separator = false
        end 
      end
      ret_type = type_constraint colon: true, explicit: true
    elsif token == ":"
      ret_type = type_constraint colon: false, explicit: true
    else
      unexpected! "( or :"
    end

    unless extern
      consume? NEWLINE
      expect! "{"
      consume? NEWLINE
      loop do
        case next_token?
        when "}" then break
        else # HANDLE STATEMENT
        end
      end
    end

    variables = nil
    statements = nil
    Function.new name, parameters, ret_type, (variables || [] of Variable), (statements || [] of Statement), extern: extern != nil
  end

  def unit
    elements = [] of Requirement | Function | Variable | Struct
    loop do
      consume? NEWLINE
      case next_token?
      #when "require" then
      #when "var" then
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

  # Consume a token and raise if it not equal to *expected*
  def expect!(expected)
    unexpected! expected.dump unless next_token? == expected
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

  # Return true and consume the current token if it is equal to *token* parameter.
  # return false otherwise.
  def consume?(token)
    if @tokens[@index]?.try(&.value) == token
      @index += 1
      return true
    else
      return false
    end
  end

  # True if End Of File is reached.
  def eof?
    @index >= @tokens.size
  end

  # Get the ,next token. Raise if none. 
  # Parameter *expected* is used to document the raised error.
  def next_token!(expected)
    (@tokens[@index]? || unexpected! expected).tap do 
      @index += 1
    end.value
  end

   # Get the, next token if any
  def next_token?
    @tokens[@index]?.try &.value.tap do 
      @index += 1
    end
  end


  @filename : String?
  def initialize(io : IO, @filename = nil)
    @tokens = Lexer.run io
    pp @tokens.map(&.value)
    @index = 0
  end
end

File.open ARGV.first do |file|
  puts Stacklang::Parser.new(file).unit
end