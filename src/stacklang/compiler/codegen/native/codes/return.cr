class Stacklang::Native::Generator  
  
  def compile_return(code : ThreeAddressCode::Return)
    meta = @addresses[root_id code.address]
    jump_address_register = load code.address
    jalr ZERO_REGISTER, jump_address_register
  end
end