require "./codes"
require "./translator"

module Stacklang::ThreeAddressCode
  # Given block of code and the context, produce an array of three address code.
  # *unit* is used to pull type and function definitions,
  # *function* is the optional function being translated and is provided for
  #   providing additional context in case of error
  # *context* is a mapping of all reachable named address and there type.
  # Usually this mean globals, parameters and variables declared within the block.
  def self.translate(function)
    Translator.new(function).translate
  end
end
# TODO: remove types from tacs array
# Label, BEQ, B, Call
# Automatically be smart about nand and add when possible
# 
# Local load (local() = t0) (usually we do  *t0 = t1) => require Move
#     and so lvalue can return local/global 
# 
# Complex assignment
# 
# TODO: io type & function type