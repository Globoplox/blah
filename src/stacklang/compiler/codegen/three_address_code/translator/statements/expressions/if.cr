struct Stacklang::ThreeAddressCode::Translator
  def translate_if(expression : AST::If)
    condition = translate_expression expression.condition
    if condition.nil?
      raise Exception.new "Expression has no type", expression.condition, @function
    end
    condition_address, condition_typeinfo = condition

    label = "end_of_if_#{next_uid}"
    zero = Immediate.new 0, expression
    @tacs << JumpEq.new(label, {condition_address, zero}, expression)

    current_scope = @scope
    @scope = Scope.new(@scope, expression.body, @function, @next_uid)

    expression.body.each do |statement|
      translate_statement statement
    end

    @scope = current_scope
    @tacs << Label.new label, expression

  end
end

# How to handle: complex || &&:
# set a stack of escape true / escape false symbols to jump 
# when starting a if, while, Create a new pair of escape symbol on a stack, remove once expression computed
# when ||, &&, if there is a pair use it, else create a new and remove after
# on ||, before left side eval, set the success symbol to it's own success symbol, set the false symbol to go back to the 
# 
# or(if_false, if_true) {
#   idk = new_symbol
#   check_if_true(left_expression, idk, if_true)
#   check_if_true(right_expression, if_false, if_true)
# }
#
# and(if_false, if_true) {
#   idk = new_symbol
#   check_if_true(left_expression, if_false, idk)
#   check_if_true(right_expression, if_false, if_true)
# }
#
# check_if_true(exression, if_false, if_true) {
#   JumpEq expression, 0, if_false
#   jumpEq 0, 0, if_true 
# }
#
# and then we can write a bunch of optimisation of ==, !=, < > <= >= operators to call if_false if_true instead of producing a 0 or 1 value
#
# Optimization:
# - ensure that jump eq use beq beq movi jalr order (so movi is always before jalr)
# - then add a post compilation pass that find all movi jalr on fill spill that use a local symbol that would work as a beq,
#    and compress the movi jalr to a beq (move defined symbols too !)
#    run this loop until no result
# - then add a loop that detect when a A: beq +-n lead a B: beq r0 r0 sym and if the sym + B - A, idk u got it
#
#
# A beq n
# ...
# B beq sym
# ....
# sym
#
#
# sym - A fit in beq
