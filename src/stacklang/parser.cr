require "../parsing/primitive"
require "./ast"

# FIXME: line and char counts
# TODO: Function PTR
class Stacklang::Parser < Parser
  include Stacklang::AST

  rule def identifier
    next unless chars = one_or_more ->{ char ['a'..'z', '_'..'_'] }
    Identifier.new chars.join
  end

  rule def separator
    whitespace
    next unless sep = char ',' 
    whitespace
    sep
  end

  # Greedely consume any whitespace or comment, but ensure at least one ; or newline has been consumed.
  def expression_separators
    separator = false
    loop do
      check = @io.tell
      line = @line
      character = @character
      case c = @io.gets 1
      when ";"
        @character += 1
        separator = true
      when "\n"
        @character = 0
        @line += 1
        separator = true
      when " ", "\t", "\r"
        @character += 1
        next
      when "/"
        @character += 1
        c = @io.gets 1
        if c == "/"
          @character += 1
          consume_until "\n"
        else
          @io.pos = check
          @line = line
          @character = character
          break
        end
      else
        @io.pos = check
        @line	= line
        @character =	character
        break
      end
    end
    separator == true ? true : nil
  end

  rule def statement_if
    next unless str "if"
    whitespace
    next unless char '('
    multiline_whitespace
    next unless condition = expression
    multiline_whitespace
    next unless char ')'
    multiline_whitespace
    statements : Array(Statement) = if char '{'
      expression_separators
      _statements = zero_or_more ->any_statement, separated_by: ->expression_separators
      expression_separators
      next unless char '}'
      _statements
    else
      next unless stat = any_statement
      [stat]
    end
    If.new condition, statements
  end

  rule def statement_return
    next unless str "return"
    whitespace
    expr = expression 
    Return.new expr
  end

  rule def statement_while
    next unless str "while"
    whitespace
    next unless char '('
    multiline_whitespace
    next unless condition = expression
    multiline_whitespace
    next unless char ')'
    multiline_whitespace
    statements = if char '{'
      expression_separators
      _statements = zero_or_more ->any_statement, separated_by: ->expression_separators
      expression_separators
      next unless char '}'
      _statements
    else
      next unless stat = any_statement
      [stat]
    end
    While.new condition, statements
  end

  rule def call
    next unless name = identifier
    whitespace
    next unless char '('
    parameters = zero_or_more ->expression, separated_by: ->separator
    next unless char ')'
    Call.new name, parameters
  end

  rule def unary_operation
    next unless operator = str ["!", "*", "&", "-", "~"]
    next unless expr = leaf_expression
    # Has to be leaf else *foo.bar would be *(foo.bar) instead of (*foo).bar
    # and more importantly *foo = bar would be *(foo = bar)
    # So if we want to use an unary on a complex expression, wrap it with parenthesis
    Unary.new expr, operator
  end

  rule def sizeof
    next unless str "sizeof"
    whitespace
    next unless char '('
    whitespace
    next unless constraint = type_constraint false, true
    whitespace
    next unless char ')'
    Sizeof.new constraint
  end

  rule def cast
    next unless char '('
    whitespace
    next unless constraint = type_constraint false, true
    whitespace
    next unless separator
    whitespace
    next unless target =  expression
    whitespace
    next unless char ')'
    Cast.new constraint, target
  end

  def leaf_expression
    or ->sizeof, ->cast, ->literal, ->unary_operation, ->parenthesis, ->call, ->identifier
  end

  rule def affectation_chain
    next unless name = str ["=", "-=", "+=", "&=", "~=", "|=", "<<=", ">>="]
    whitespace
    next unless right = low_priority_operation
    whitespace
    {name, right}
  end

  # Please note that all Binary operation are flattened and then
  # Linked into a tree of expression with varying kind of associativity
  # depending on the operator. See #Binary.from_chain
  
  rule def affectation_operation
    next unless left = low_priority_operation
    whitespace
    chain = zero_or_more ->affectation_chain
    Binary.from_chain left, chain
  end
  
  rule def low_chain
    next unless name = str ["&", "|", "~&", "~|", "<<", ">>", "+", "-"]
    whitespace
    next unless right = medium_priority_operation
    whitespace
    {name, right}
  end
  
  rule def low_priority_operation
    next unless left = medium_priority_operation
    whitespace
    chain = zero_or_more ->low_chain
    Binary.from_chain left, chain
  end

  rule def medium_chain
    next unless name = str ["**", "*", "/", "%"]
    whitespace
    next unless right = high_priority_operation
    whitespace
    {name, right}
  end
  
  rule def medium_priority_operation
    next unless left = high_priority_operation
    whitespace
    chain = zero_or_more ->medium_chain
    Binary.from_chain left, chain
  end

  rule def high_chain
    next unless name = str ["<=", ">=", "==", "!=", "||", "&&", "<", ">", "^"]
    whitespace
    next unless right = access
    whitespace
    {name, right}
  end

  rule def high_priority_operation
    next unless left = access
    whitespace
    chain = zero_or_more ->high_chain
    Binary.from_chain left, chain
  end

  rule def access_chain
    next unless char '.'
    next unless id = identifier
    id
  end  
  
  rule def access
    next unless expr = leaf_expression
    chain = zero_or_more ->access_chain
    chain.reduce(expr) do |expr, field|
      Access.new expr, field
    end
  end
  
  def operation
    affectation_operation
  end

  rule def number
    sign = str(["-", "+"]) || ""
    case str ["0x", "0b"]
    when "0x" then base = 16
    when "0b" then base = 2
    else base = 10
    end
    next unless digits = one_or_more ->{ char ['0'..'9', 'a'..'f', 'A'..'F'] }
    begin
      Literal.new (sign + digits.join).to_i32 base: base
    rescue
      nil
    end
  end
  
  def literal
    number
  end

  rule def parenthesis
    next unless char '('
    multiline_whitespace
    expr = expression
    multiline_whitespace
    next unless char ')'
    expr
  end

  def expression
    operation
  end

  def any_statement : Statement?
    or ->statement_if, ->statement_while, ->statement_return, ->expression
  end

  rule def type_name
    next unless head = char 'A'..'Z'
    tail = zero_or_more ->{ char ['A'..'Z', 'a'..'z', '0'..'1', '_'..'_'] }
    return String.build do |io|
      io << head
      tail.each do |tail_char|
        io << tail_char
      end
    end
  end

  rule def type_constraint(colon = true, explicit = false)
    if colon
      next (explicit ? nil : Word.new) unless char ':'
    end

    whitespace
    if ptr = char '*'
      type_constraint(false).try do |constraint|
        Pointer.new constraint
      end
    elsif name = type_name
      Custom.new name
    elsif char '_'
      Word.new
    elsif !explicit
      Word.new
    end
  end
  
  rule def variable
    next unless str "var"
    next unless whitespace
    next unless name = identifier
    whitespace
    next unless constraint = type_constraint
    whitespace
    char '='
    whitespace
    init = expression
    Variable.new name, constraint, init
  end

  rule def struct_field
    next unless name = identifier
    whitespace
    next unless constraint = type_constraint
    Struct::Field.new name, constraint
  end
  
  rule def struct_def
    next unless str "struct"
    next unless whitespace
    next unless name = type_name
    multiline_whitespace
    next unless char '{'
    expression_separators
    next unless fields = one_or_more ->struct_field, separated_by: ->expression_separators
    expression_separators
    next unless char '}'
    Struct.new name, fields
  end

  rule def requirement
    next unless str "require"
    next unless whitespace
    next unless char '"'
    next unless filename = consume_until "\""
    next unless char '"'
    Requirement.new filename
  end

  rule def function_parameter
    next unless name = identifier
    whitespace
    next unless constraint = type_constraint
    Function::Parameter.new name, constraint
  end

  rule def function
    next unless str "fun"
    next unless whitespace
    next unless name = identifier
    
    parameters = checkpoint do
      next unless char '('
      next unless params = one_or_more ->function_parameter, separated_by: ->separator
      next unless char ')'
      params
    end || [] of Function::Parameter
    whitespace
    ret_type = type_constraint explicit: true
    
    multiline_whitespace
    next unless char '{'
    expression_separators
    
    variables = zero_or_more ->variable, separated_by: ->expression_separators
    if variables.empty?
      expression_separators
    else
      next unless expression_separators
    end
    
    statements = zero_or_more ->any_statement, separated_by: ->expression_separators
    expression_separators
    next unless char '}'
    Function.new name, parameters, ret_type, variables, statements
  end

  def top_level
    or ->requirement, ->function, ->variable, ->struct_def
  end

  rule def unit
    expression_separators
    elements = zero_or_more ->top_level, separated_by: ->expression_separators
    expression_separators
    next unless read_fully?
    Unit.from_top_level elements
  end
  
end
