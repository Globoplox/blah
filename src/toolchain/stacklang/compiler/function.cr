class Stacklang::Function
  class Parameter
    property ast : AST::Function::Parameter
    # Before calling the function, the parameter must be wrote in the stack at offset:
    property offset : Int32
    property name : String
    property constraint : Type

    def initialize(@ast, @name, @constraint, @offset)
    end
  end

  property parameters : Array(Parameter)
  property return_type : Type?
  # After calling this function, the return value can be found in the staskat offset:
  property return_value_offset : Int32?
  property name : String
  property symbol : String
  property ast : AST::Function
  property unit : Unit

  # Check a block to ensure that it terminates.
  def deep_check_termination(ast, body)
    return ast if body.empty?
    last = body[-1]
    case last
    when AST::Return         then nil
    when AST::If, AST::While then deep_check_termination last, last.body
    else                          ast
    end
  end

  def check_fix_termination(events)
    non_returning_block = deep_check_termination @ast, @ast.body
    if non_returning_block
      if @return_type
        
        events.error(title: "Missing return", line: non_returning_block.token.line, column: non_returning_block.token.line) do |io|
          io << "Function of type '#{events.emphasis(@return_type)}' does not return in all branches"
        end

      else
        @ast.body << AST::Return.new @ast.token, nil
      end
    end
  end

  def initialize(@ast, @unit)
    @name = @ast.name.name
    @symbol = "__function_#{name}"
    @return_type = @ast.return_type.try { |constraint| @unit.typeinfo constraint }
    @return_value_offset = @return_type.try { 0 }

    offset = @return_type.try(&.size.to_i) || 0
    @parameters = @ast.parameters.map do |parameter|
      typeinfo = @unit.typeinfo(parameter.constraint)
      parameter = Parameter.new(
        ast: parameter,
        name: parameter.name.name,
        constraint: typeinfo,
        offset: offset
      )
      offset += typeinfo.size
      parameter
    end
  end
end
