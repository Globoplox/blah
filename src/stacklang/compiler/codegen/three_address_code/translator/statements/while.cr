struct Stacklang::ThreeAddressCode::Translator
  def translate_while(expression : AST::While)
    uid = next_uid
    label_condition = "__while_#{uid}_condition"
    label_start = "__while_#{uid}_start"
    label_end = "__while_#{uid}_end"

    @tacs << Label.new label_condition, expression

    translate_conditional expression.condition, ConditionalJumps.new if_true: label_start, if_false: label_end

    @tacs << Label.new label_start, expression

    current_scope = @scope
    @scope = Scope.new(@scope, expression.body, @function, @next_uid)
    expression.body.each do |statement|
      translate_statement statement
    end
    @tacs << JumpEq.new(label_condition, nil, expression)
    @scope = current_scope

    @tacs << Label.new label_end, expression
  end
end
