class Stacklang::Native::Generator  

  def compile_store(code : ThreeAddressCode::Store)
    if code.address.size != code.value.size
      raise "Size mismatch in store #{code}"
    elsif code.value.size == 1
      address = load code.address
      value = load code.value
      sw value, address, 0
      clear(read: {code.address, code.value}, written: Tuple().new)
    else 
      # TODO
      raise "Multi word store is unsupported yet"
    end
  end
end