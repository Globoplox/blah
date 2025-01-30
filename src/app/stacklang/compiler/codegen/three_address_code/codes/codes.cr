require "./*"

module Stacklang::ThreeAddressCode
  alias Code = Add | Nand | Reference | Move | Call | Return | Start | Load | Store | Label | JumpEq
end
