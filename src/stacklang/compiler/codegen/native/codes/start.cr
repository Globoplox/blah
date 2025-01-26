class Stacklang::Native::Generator  

  def compile_start(code : ThreeAddressCode::Start)
    meta = @addresses[root_id code.address]
    meta.set_live_in_register for: code.address, register: CALL_RET_REGISTER
    @registers[CALL_RET_REGISTER] = code.address
    clear read: [] of ThreeAddressCode::Address, written: [code.address]
  end
end