# TODO: nice errors
# TODO: creating immediate address hosting global / function address, so they can be hosted in registers
# TODO: a flag on meta "written" that is set when well written, so we do not spill address that are loaded but have not been written since load
# TODO: global initialization
module Stacklang::Native
  def self.generate_global_section(globals) : RiSC16::Object::Section
    section = RiSC16::Object::Section.new "globals"
    code = [] of RiSC16::Word
    globals.each do |global|
      section.definitions[global.symbol] = RiSC16::Object::Section::Symbol.new code.size, true
      global.typeinfo.size.times do
        code << 0u16
      end
      section.text = Slice.new code.size do |i|
        code[i]
      end
    end
    section
  end

  def self.generate_function_section(function : Function, codes : Array(ThreeAddressCode::Code), events : Toolchain::EventStream) : RiSC16::Object::Section
    Generator.new(function, codes, events).generate
  end

  class Stacklang::Native::Generator
  end
end

require "./*"
