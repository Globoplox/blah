require "../parsing/primitive"
require "./ast"

class Stacklang::Parser < Parser
  include Stacklang::AST

  def identifier
    checkpoint "identifier" do
      Identifier.new (mandatory one_or_more(char(['a'..'z', '_'..'_']))).join
    end
  end

  def separator
    checkpoint "separator" do
      whitespace
      sep = mandatory char ',' 
      whitespace
      sep
    end
  end

  # Greedely consume any whitespace or comment, but ensure at least one ; or newline has been consumed.
  def expression_separators
    separator = false
    loop do
      check = @io.tell
      case c = @io.gets 1
      when ";", "\n" then separator = true
      when " ", "\t", "\r" then next
      when "/"
        c = @io.gets 1
        if c == "/"
          consume_until "\n"
        else
          @io.pos = check
          break
        end
      else
        @io.pos = check
        break
      end
    end
    separator == true ? true : nil
  end

  def statement_if
    checkpoint "if statement" do
      mandatory str "if"
      whitespace
      mandatory char '('
      multiline_whitespace
      condition = mandatory expression
      multiline_whitespace
      mandatory char ')'
      multiline_whitespace
      statements : Array(Statement) = if char '{'
        expression_separators
        _statements = zero_or_more any_statement, separated_by: expression_separators
        expression_separators
        mandatory char '}'
        _statements
      else
        [mandatory any_statement]
      end
      If.new condition, statements
    end
  end

  def statement_return
    checkpoint "return statement" do
      mandatory str "return"
      mandatory whitespace
      Return.new mandatory expression
    end
  end

  def statement_while
    checkpoint "while statement" do
      mandatory str "while"
      whitespace
      mandatory char '('
      multiline_whitespace
      condition = mandatory expression
      multiline_whitespace
      mandatory char ')'
      multiline_whitespace
      statements = if char '{'
        expression_separators
        _statements = zero_or_more any_statement, separated_by: expression_separators
        expression_separators
        mandatory char '}'
        _statements
      else
        [mandatory any_statement]
      end
      While.new condition, statements
    end
  end

  def call
    checkpoint "call" do
      name = mandatory identifier
      whitespace
      mandatory char '('
      parameters = zero_or_more expression, separated_by: separator
      mandatory char ')'
      Call.new name, parameters
    end
  end

  def unary_operation
    checkpoint "unary_operation" do
      operator = mandatory str ["!", "*", "&"]
      Unary.new mandatory(expression), operator
    end
  end

  def leaf_expression
    or(unary_operation, parenthesis, call, identifier, literal)
  end
  
  def low_chain
    checkpoint "low_chain" do
      name = mandatory str ["&", "|", "^", "+", "-"]
      whitespace
      right = mandatory medium_priority_operation
      whitespace
      {name, right}
    end
  end
  
  def low_priority_operation
    checkpoint "low priority operation" do
      left = mandatory medium_priority_operation
      whitespace
      chain = zero_or_more low_chain
      Binary.from_chain left, chain
    end
  end

  def medium_chain
    checkpoint "medium_chain" do
      name = mandatory str ["**", "*", "/", "%"]
      whitespace
      right = mandatory high_priority_operation
      whitespace
      {name, right}
    end
  end
  
  def medium_priority_operation
    checkpoint "medium priority operation" do
      left = mandatory high_priority_operation
      whitespace
      chain = zero_or_more medium_chain
      Binary.from_chain left, chain
    end
  end

  def high_chain
    checkpoint "high_chain" do
      name = mandatory str ["<=", ">=", "==", "!=", "||", "&&", "<", ">", "^"]
      whitespace
      right = mandatory affectation_operation
      whitespace
      {name, right}
    end
  end

  def high_priority_operation
    checkpoint "high priority operation" do
      left = mandatory affectation_operation
      whitespace
      chain = zero_or_more high_chain
      Binary.from_chain left, chain
    end
  end

   def affectation_chain
    checkpoint "affectation_chain" do
      name = mandatory str "="
      whitespace
      right = mandatory access
      whitespace
      {name, right}
    end
  end
  
  def affectation_operation
    checkpoint "affectation_operation" do
      left = mandatory access
      whitespace
      chain = zero_or_more affectation_chain
      Binary.from_chain left, chain
    end
  end

  def access_chain
    checkpoint "access_chain" do
      mandatory char '.'
      mandatory identifier
    end
  end  
  
  def access
    checkpoint "access" do
      expr = mandatory leaf_expression
      chain = zero_or_more access_chain
      chain.reduce(expr) do |expr, field|
        Access.new expr, field
      end
    end
  end
  
  def operation
    low_priority_operation
  end

  def number
    checkpoint "literal" do
      base = str "0x"
      Literal.new (mandatory one_or_more(char ['0'..'9', 'a'..'f', 'A'..'F'])).join.to_i32(base: base ? 16 : 10)
    end
  end
  
  def literal
    number
  end

  def parenthesis
    checkpoint "parenthesis" do
      mandatory char '('
      multiline_whitespace
      expr = expression
      multiline_whitespace
      mandatory char ')'
      expr
    end
  end

  def expression
    operation
  end

  def any_statement : Statement?
    or(statement_if, statement_while, statement_return ,expression)
  end

  def type_name
    checkpoint "type_name" do
      head = mandatory char 'A'..'Z'
      tail = zero_or_more char	['A'..'Z', 'a'..'z', '0'..'1', '_'..'_']
      return String.build do |io|
        io << head
        tail.each do |tail_char|
          io << tail_char
        end
      end
    end
  end

  def type_constraint(colon = true)
    checkpoint "type_constraint" do
      if colon
        mandatory char ':'
      end
      whitespace
      if ptr = char '*'
        type_constraint(false).try do |constraint|
          Pointer.new constraint
        end
      else
        Custom.new mandatory type_name
      end
    end || Word.new
  end
  
  def variable
    checkpoint "variable_definition" do
      mandatory str "var"
      mandatory whitespace
      name = mandatory identifier
      whitespace
      constraint = type_constraint
      whitespace
      char '='
      whitespace
      init = expression
      Variable.new name, constraint, init
    end
  end

  def struct_field
    checkpoint "structure_field_definition" do
      name = mandatory identifier
      whitespace
      constraint = type_constraint
      Struct::Field.new name, constraint
    end
  end
  
  def struct_def
    checkpoint "structure_definition" do
      mandatory str "struct"
      mandatory whitespace
      name = mandatory type_name
      multiline_whitespace
      mandatory char '{'
      expression_separators
      fields = mandatory one_or_more struct_field, separated_by: expression_separators
      expression_separators
      mandatory char '}'
      Struct.new name, fields
    end
  end

  def requirement
   checkpoint "requirement" do
     mandatory str "require"
     mandatory whitespace
     mandatory char '"'
     filename = mandatory consume_until "\""
     mandatory char '"'
     Requirement.new filename
   end
  end

  def function_parameter
    checkpoint "function_parameter" do
      name = mandatory identifier
      whitespace
      constraint = type_constraint
      Function::Parameter.new name, constraint
    end
  end

  def function
    checkpoint "function prototype" do
      mandatory str "fun"
      mandatory whitespace
      name = mandatory identifier

      parameters = checkpoint "function parameters" do
        mandatory char '('
        params = mandatory one_or_more function_parameter, separated_by: separator
        mandatory char ')'
        params
      end || [] of Function::Parameter
      whitespace
      ret_type = type_constraint

      multiline_whitespace
      mandatory char '{'
      expression_separators

      variables = zero_or_more variable, separated_by: expression_separators
      if variables.empty?
        expression_separators
      else
        mandatory expression_separators
      end

      statements = zero_or_more any_statement, separated_by: expression_separators
      expression_separators
      mandatory char '}'

      Function.new name, parameters, ret_type, variables, statements
    end
  end

  def top_level
    or(requirement, function, variable, struct_def)
  end

  def unit
    checkpoint "unit" do
      expression_separators
      elements = zero_or_more top_level, separated_by: expression_separators
      expression_separators
      mandatory read_fully?
      Unit.from_top_level elements
    end
  end
  
end

pp Stacklang::Parser.new(IO::Memory.new(ARGF.gets_to_end), true).unit
