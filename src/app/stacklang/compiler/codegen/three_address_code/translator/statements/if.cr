struct Stacklang::ThreeAddressCode::Translator
  def translate_if(expression : AST::If)
    uid = next_uid
    label_start = "__if_#{uid}_start"
    label_end = "__if_#{uid}_end"

    translate_conditional expression.condition, ConditionalJumps.new if_true: label_start, if_false: label_end

    @tacs << Label.new label_start, expression

    current_scope = @scope
    @scope = Scope.new(@scope, expression.body, @function, @next_uid)
    expression.body.each do |statement|
      translate_statement statement
    end
    @scope = current_scope

    @tacs << Label.new label_end, expression
  end
end
