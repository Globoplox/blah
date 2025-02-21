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
        @events.error(title: "Expression has no type", line: expression.left.token.line, column: expression.left.token.character) {}
        return
      end
      address, typeinfo = left

      unless typeinfo.is_a? Type::Table
        @events.error(title: "Type error", line: expression.token.line, column: expression.token.character) do |io|
          io << "Cannot access element [#{@events.emphasis(expression.right)}] of non table type #{@events.emphasis(typeinfo.to_s)}"
        end
        return
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
        @events.error(title: "Invalid struct access", line: expression.left.token.line, column: expression.left.token.character) do |io|
          io << "Not a valid lvalue"
        end
        return
      end
    end
  end

  def translate_table_access(expression : AST::Binary) : {Address, Type}?
    table_access_as_address?(expression) || translate_expression(convert_table_access(expression))
  end
end
