class Stacklang::Native::Generator  
  def compile_add(code : ThreeAddressCode::Add)
    raise "Bad operand size for value in add: #{code}" if code.into.size > 1 || code.left.size > 1 || code.right.size > 1
    left = load code.left
    right = load code.right
    into = grab_for code.into
    add into, left, right
    clear(read: {code.left, code.right}, written: {code.into})
  end
end
