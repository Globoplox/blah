struct Stacklang::ThreeAddressCode::Translator
  def convert_table_access(expression : AST::Binary) : AST::Expression
    AST::Unary.new(
      token: expression.token,
      operand: AST::Binary.new(
        token: expression.token,
        left: AST::Unary.new(
          token: expression.token,
          operand: expression.left,
          name: "&",
        ),
        right: expression.right,
        name: "+",
      ),
      name: "*"
    )
  end

  # If this table access expression can be solved easely to a single address, return this address.
  def table_access_as_address?(expression : AST::Binary) : {Address, Type}?
    expression.right.as?(AST::Literal).try do |literal_index|
      left = translate_expression expression.left
      if left.nil?
        raise Exception.new "Expression has no type", expression.left, @function
      end
      address, typeinfo = left

      unless typeinfo.is_a? Type::Table
        raise Exception.new "Cannot access element [#{expression.right}] of non table type #{typeinfo}", expression, @function
      end

      if address.is_a?(Local)
        address = Local.new address.uid, address.offset + literal_index.number, typeinfo.table_of.size.to_i, expression, restricted: address.restricted
        return {address, typeinfo.table_of}
      elsif address.is_a?(Global)
        address = Global.new address.name, typeinfo.table_of.size.to_i, expression, address.offset + literal_index.number
        return {address, typeinfo.table_of}
      elsif address.is_a?(Anonymous)
        address = Anonymous.new address.uid, typeinfo.table_of.size.to_i, address.offset + literal_index.number
        return {address, typeinfo.table_of}
      else
        raise "Invalid left side of access #{expression.left}"
      end
    end
  end

  def translate_table_access(expression : AST::Binary) : {Address, Type}?
    table_access_as_address?(expression) || translate_expression(convert_table_access(expression))
  end
end
