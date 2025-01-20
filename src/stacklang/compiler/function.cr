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
   def deep_check_termination(body)
    return false if body.empty?
    last = body[-1]
    case last
    when AST::Return then true
    when AST::If, AST::While then deep_check_termination last.body
    else false
    end
  end

  def check_fix_termination
    unless deep_check_termination @ast.body
      if @return_type
        raise "Function '#{name}'returning #{@return_type} does not always return"
      else
        @ast.body << AST::Return.new @ast.token, nil
      end
    end
  end
  
  def initialize(@ast, @unit)
    @name = @ast.name.name
    @symbol = "__function_#{name}"
    @return_type = @ast.return_type.try { |constraint| @unit.typeinfo constraint }
    @return_value_offset = @return_type.try &.size.to_i.* -1

    offset = (@return_value_offset || 0) + 1
    @parameters = @ast.parameters.map do |parameter|
      typeinfo = @unit.typeinfo(parameter.constraint)
      Parameter.new(
        ast: parameter,
        name: parameter.name.name,
        constraint: typeinfo,
        offset: (offset -= typeinfo.size)
      )
    end
  end
end
