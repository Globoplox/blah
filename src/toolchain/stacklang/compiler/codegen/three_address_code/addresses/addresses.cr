require "./*"

module Stacklang::ThreeAddressCode
  alias Address = Anonymous | Local | Global | Immediate | Function
end
