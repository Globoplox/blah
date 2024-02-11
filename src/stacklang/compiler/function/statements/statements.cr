class Stacklang::Function

  # Compile a if or while statement.
  def compile_if(if_node : AST::If | AST::While, loop = false)
    symbol_start = "__block_start_#{@local_uniq += 1}_#{Base64.encode(if_node.condition.to_s[0..13])}"
    symbol_end = "__block_end_#{@local_uniq += 1}_#{Base64.encode(if_node.condition.to_s[0..13])}"
    store_all
    result_register = grab_register

    size_of_block = predict_size do
      if_node.body.each do |statement|
        compile_statement statement
      end
      store_all
    end

    size_of_condition = predict_size do
      condition_type = compile_expression if_node.condition, into: result_register
    end

    @section.definitions[symbol_start] = Object::Section::Symbol.new @text.size, false if loop
    condition_type = compile_expression if_node.condition, into: result_register
    error "Condition expression expect a word or a pointer, got #{condition_type}", node: if_node if condition_type.is_a?(Type::Struct)

    if size_of_block < 60
      beq result_register, Registers::R0, symbol_end
    else
      beq result_register, Registers::R0, 1u16
      beq Registers::R0, Registers::R0, predict_movi(result_register, symbol_end) + 1u16
      movi result_register, symbol_end
      jalr Registers::R0, result_register
    end

    if_node.body.each do |statement|
      compile_statement statement
    end
    store_all

    if loop
      if size_of_block + size_of_condition < 60
        beq Registers::R0, Registers::R0, symbol_start
      else
        movi result_register, symbol_start
        jalr Registers::R0, result_register
      end
    end

    @section.definitions[symbol_end] = Object::Section::Symbol.new @text.size, false
  end

  # Compile any statement.
  def compile_statement(statement)
    case statement
    when AST::Return     then compile_return statement
    when AST::If         then compile_if statement
    when AST::While      then compile_if statement, loop: true
    when AST::Expression then compile_expression statement, nil
    when AST::Variable
      if value = statement.initialization
        compile_assignment statement.name, value, nil
      end
    @variables[statement.name.name].initialized = true
    end
  end
end
