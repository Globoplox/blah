struct Stacklang::ThreeAddressCode::Translator
  def translate_access(expression : AST::Access) : {Address, Type}?
    left = translate_expression expression.operand
    if left.nil?
      @events.error(title: "Expression has no type", line: expression.operand.token.line, column: expression.operand.token.character) {}
      return
    end
    address, typeinfo = left

    unless typeinfo.is_a? Type::Struct
      @events.error(title: "Invalid struct access", line: expression.token.line, column: expression.token.character) do |io|
        io << "Cannot access field #{@events.emphasis(expression.field.name)} in non-structure type #{@events.emphasis(typeinfo.to_s)}"
      end
      return
    end

    field = typeinfo.fields.find &.name.== expression.field.name

    unless field
      @events.error(title: "Invalid struct access", line: expression.token.line, column: expression.token.character) do |io|
        io << "No field named #{@events.emphasis(expression.field.name)} in structure #{@events.emphasis(typeinfo.to_s)}"
      end
      return
    end

    if address.is_a?(Local)
      address = Local.new address.uid, address.offset + field.offset.to_i, field.constraint.size.to_i, expression, restricted: address.restricted
      {address, field.constraint}
    elsif address.is_a?(Global)
      address = Global.new address.name, field.constraint.size.to_i, expression, address.offset + field.offset.to_i
      {address, field.constraint}
    elsif address.is_a?(Anonymous)
      address = Anonymous.new address.uid, field.constraint.size.to_i, address.offset + field.offset.to_i
      {address, field.constraint}
    else
      @events.error(title: "Invalid struct access", line: expression.token.line, column: expression.token.character) do |io|
        io << "Not a valid lvalue"
      end
      return
    end
  end
end
