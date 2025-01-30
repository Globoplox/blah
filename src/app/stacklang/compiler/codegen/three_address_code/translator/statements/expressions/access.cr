struct Stacklang::ThreeAddressCode::Translator
  def translate_access(expression : AST::Access) : {Address, Type}
    left = translate_expression expression.operand
    if left.nil?
      raise Exception.new "Expression has no type", expression.operand, @function
    end
    address, typeinfo = left

    unless typeinfo.is_a? Type::Struct
      raise Exception.new "Cannot access field #{expression.field.name} of type #{typeinfo}", expression, @function
    end

    field = typeinfo.fields.find &.name.== expression.field.name

    unless field
      raise Exception.new "No field named #{expression.field.name} in structure #{typeinfo}", expression, @function
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
      raise "Invalid left side of access #{expression.operand}"
    end
  end
end
