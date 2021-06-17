class RiSC16::Object
  @name : String?
  @sections : Array(Section) = [] of Section
  getter sections

  def initialize(@name) end

  class	Section
    property name : String
    property offset : Int32? = nil
    property text : Slice(UInt16) = Slice(UInt16).empty
    property definitions : Hash(String, Symbol) = {} of String => Symbol
    property references : Hash(String, Array(Reference)) = {} of String => Array(Reference)

    def initialize(@name, @offset = nil) end
    
    class Symbol
      # We migh want negative 'address' for predefined symbols with negative value
      property address : Int32 # relative to owner section @text  
      property exported	: Bool
      def initialize(@address, @exported) end
    end

    class Reference
      property address : UInt16
      property offset : Int32
      property kind : Kind
      enum Kind
	Imm # 7bit signed
        Lui # total >> 6
        Lli # total & 0x3v
	Data # 16 bit
        Beq # in this case, the linker must do offset + symbol - real_instruction_addres - 1, before fitting to signed 7 bit
            # (we could presolve it if we knew the symbol is in the same section  but it might neot be the case)
      end
      def initialize(@address, @offset, @kind) end
    end
  end
end
