class Stacklang::Native::Generator  

  def compile_label(code : ThreeAddressCode::Label)
    if @section.definitions.has_key? code.name
      raise "Duplicate label declaration #{code.name} is declared at 0x#{@section.definitions[code.name].address.to_s base: 16} and 0x#{@text.size.to_s base: 16}"
    end 

    # Must unload ALL because we cant garantee that the value cached will be the same when something jump here.
    # We must have no cache before creating the label, and before jumping to it so we can ensure
    # everytime we reach this label (normally or through jump), the state is the same.
    unload_all

    @section.definitions[code.name] = RiSC16::Object::Section::Symbol.new @text.size, false
  end
end