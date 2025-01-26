class Stacklang::Native::Generator  

  def compile_ref(code : ThreeAddressCode::Reference)
    raise "Bad operand size for value in ref: #{code}" if code.into.size > 1
    into = grab_for code.into
    load_raw_address code.address, into
    # If we took the address of a local variable, consider that it is unsafe to keep cache of it
    # or of any of it fields as their memory location might now be accessed in other ways.
    if local = code.address.as?(ThreeAddressCode::Local)
      restrict local
    end
    clear(read: Tuple().new, written: {code.into})
  end
end