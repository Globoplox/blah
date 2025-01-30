require "./stack"
require "./metadata"
require "./load_unload"
require "./codes/*"

class Stacklang::Native::Generator
  enum Register : UInt16
    R0 = 0u16
    R1 = 1u16
    R2 = 2u16
    R3 = 3u16
    R4 = 4u16
    R5 = 5u16
    R6 = 6u16
    R7 = 7u16
  end

  # Hold the stack pointer
  STACK_REGISTER = Register::R7

  # Zero register, always read as 0, write discarded
  ZERO_REGISTER = Register::R0

  # Per convention, register used for storing return address on function calls
  CALL_RET_REGISTER = Register::R6

  # If all GPR registers are hosting a address that cannot be easely spilled
  # (global, further than 0x40)
  # Then it is now impossible to spill any of them without destroying another
  # There are many way to avoid this, the simplest one being
  # keeping a register that must never exclusiveley (as, not in ram) host an address.
  # We use this register for this purpose
  FILL_SPILL_REGISTER = Register::R5

  # All General Purpose Registers that can be used to store addresses values.
  # Note that it does includes the CALL_RET_REGISTER
  GPR = Register.values - [ZERO_REGISTER, STACK_REGISTER, FILL_SPILL_REGISTER]

  # List the address referenced by a code.
  def addresses_of(code : ThreeAddressCode::Code)
    case code
    in ThreeAddressCode::Add       then {code.left, code.right, code.into}
    in ThreeAddressCode::Nand      then {code.left, code.right, code.into}
    in ThreeAddressCode::Reference then {code.address, code.into}
    in ThreeAddressCode::Move      then {code.address, code.into}
    in ThreeAddressCode::Call      then code.parameters.map(&.first) + [code.address, code.into].compact
    in ThreeAddressCode::Start     then {code.address}
    in ThreeAddressCode::Return    then {code.address}
    in ThreeAddressCode::Store     then {code.address, code.value}
    in ThreeAddressCode::Load      then {code.address, code.into}
    in ThreeAddressCode::Label     then Array(ThreeAddressCode::Address).new
    in ThreeAddressCode::JumpEq    then code.operands.try(&.to_a) || [] of ThreeAddressCode::Address
    end
  end

  # Compile a single three address code
  def compile_code(code : ThreeAddressCode::Code)
    case code
    in ThreeAddressCode::Add       then compile_add code
    in ThreeAddressCode::Nand      then compile_nand code
    in ThreeAddressCode::Load      then compile_load code
    in ThreeAddressCode::Store     then compile_store code
    in ThreeAddressCode::Reference then compile_ref code
    in ThreeAddressCode::Move      then compile_move code
    in ThreeAddressCode::Call      then compile_call code
    in ThreeAddressCode::Return    then compile_return code
    in ThreeAddressCode::Start     then compile_start code
    in ThreeAddressCode::Label     then compile_label code
    in ThreeAddressCode::JumpEq    then compile_jump_eq code
    end
  end

  def generate : RiSC16::Object::Section
    @codes.each_with_index do |code, index|
      @index = index
      compile_code code
    end

    @section.text = Slice(UInt16).new @text.to_unsafe, @text.size

    @section
  end

  @stack : Stack
  @registers : Hash(Register, ThreeAddressCode::Address?)

  # Helper func that ensure state is coherent
  def stack_allocate(address)
    meta = @addresses[root_id address]
    raise "Already on stack: #{address} #{meta}" if meta.spilled_at
    meta.spilled_at = @stack.allocate address
  end

  # Helper func that ensure state is coherent
  def stack_free(address)
    meta = @addresses[root_id address]
    raise "Already free #{address} #{meta}" unless meta.spilled_at
    meta.spilled_at.try do |index|
      @stack.free index
    end
    meta.spilled_at = nil
  end

  # Address metadata holding, among other things, a stack location if any is needed,
  # and potential register hosting value for some offsets of this location
  @addresses : Hash(AddressRootId, Metadata) = {} of AddressRootId => Metadata

  alias AddressRootId = Int32 | String

  # Produce an root id to hash the addresses
  def root_id(address : ThreeAddressCode::Address) : AddressRootId
    case address
    in ThreeAddressCode::Anonymous
      0b01 << 30 | address.uid
    in ThreeAddressCode::Local
      0b00 << 30 | address.uid
    in ThreeAddressCode::Global
      address.name
    in ThreeAddressCode::Immediate
      val = address.value
      case val
      in String then val
      in Int32  then 0b10 << 30 | val
      end
    in ThreeAddressCode::Function
      address.name
    end
  end

  @codes : Array(ThreeAddressCode::Code)

  def initialize(@function : Function, @codes)
    @index = 0
    @section = RiSC16::Object::Section.new @function.symbol, options: RiSC16::Object::Section::Options::Weak
    @section.definitions[@function.symbol] = RiSC16::Object::Section::Symbol.new 0, true
    @text = [] of UInt16

    # Reverse index of registers to address
    @registers = {} of Register => ThreeAddressCode::Address?
    # Stack state
    @stack = Stack.new

    # All local addresses
    reserved_addresses = [] of ThreeAddressCode::Local

    labels = [] of String
    last_ref_to_label = {} of String => Int32
    address_used_after_label_index = {} of AddressRootId => Int32

    # Scann whole program to register addresses and compute last usage location (taking jump into account)
    # If a variable is used AFTER a label is declared, then it must stay alive (in stack) until the LAST jump to this label
    # to avoid their stack block from being freed, reused and overwritten before a jump back happen
    # (they always have a stack address before and it is spilled when reaching a label so no need to pre-allocate)
    @codes.each_with_index do |code, index|
      # Stack existing labels
      if code.is_a?(ThreeAddressCode::Label)
        labels << code.name
      end

      # Note where the last jump to a label happen
      code.as?(ThreeAddressCode::JumpEq).try do |jump|
        last_ref_to_label[jump.location] = index
      end

      addresses_of(code).each do |address|
        id = root_id address

        metadata = @addresses[id]?
        if metadata
          metadata.used_at << index
        else
          metadata = Metadata.new address, index
          @addresses[id] = metadata
          # Note abi expected address
          address.as?(ThreeAddressCode::Local).try do |address|
            reserved_addresses << address if address.abi_expected_stack_offset
          end
        end

        # Note the furthest labels declaration that this address is used after (only for spillable stuff)
        if !metadata.spillable.never?
          address_used_after_label_index[id] = labels.size
        end
      end
    end

    # For each variable, take the biggest of all the last of usages of the jump of the labels its used after, and add it to the used_at of the var
    address_used_after_label_index.each do |(address_id, last_labels_defined_before_usage)|
      # Each label defined before this variable last usage
      # (AKA, all labels at which a jump may cause issues if the variable has lost it's stack offset between the label and the jump)
      furthest_jump = nil
      (0...last_labels_defined_before_usage).each do |label_defined_before_usage|
        label = labels[label_defined_before_usage]
        last_jump_to_this_label = last_ref_to_label[label]?
        next unless last_jump_to_this_label
        if furthest_jump.nil? || furthest_jump < last_jump_to_this_label
          furthest_jump = last_jump_to_this_label
        end
      end
      # This var is defined after some labels, the last jump to those labels is at furthest_jump
      # the var must keep its stack allocated address until at least furthest_jump
      # else it may be overwritten before the jump, and the code after the label will load at a location that may have been used by another var
      # because the var has been cleared due to not being used anymore (in the order of instruction in code, but not in the order of the execution)
      @addresses[address_id].used_at << furthest_jump if furthest_jump
    end

    # Some stuff MUST be reserved on the stack immediately (if they exists):
    # return value (as it WILL be used and it is EXPECTED to be at a given place)
    # parameters (are they are actually already here, )
    reserved_addresses.sort_by(&.abi_expected_stack_offset.not_nil!).each do |reserved_local_address|
      stack_allocate reserved_local_address
    end
  end
end
