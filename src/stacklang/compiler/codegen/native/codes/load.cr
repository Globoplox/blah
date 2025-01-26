class Stacklang::Native::Generator  

  def compile_load(code : ThreeAddressCode::Load)
    if code.address.size != code.into.size
      raise "Size mismatch in load #{code}"
    elsif code.into.size == 1
      address = load code.address
      into = grab_for code.into
      lw into, address, 0
      clear(read: {code.address}, written: {code.into})
    else
      # TODO
      # must get the address of into, so intead of grab_for into, we use fill spill and put the address in it (fail for Immediate address)
      raise "Multi word load is unsupported yet"
    end
  end
end
