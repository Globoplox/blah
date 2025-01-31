require "./addresses"
require "./codes"
require "./translator"

# Three Address Code is a low level intermediary language.
# It consists of a variety of 'codes' that represent assembly like instructions
# and 'addresses' that represent different kind of values that can be manipulated.
module Stacklang::ThreeAddressCode
  # Given block of code and the context, produce an array of three address code.
  # *unit* is used to pull type and function definitions,
  # *function* is the optional function being translated and is provided for
  #   providing additional context in case of error
  # *context* is a mapping of all reachable named address and there type.
  # Usually this mean globals, parameters and variables declared within the block.
  def self.translate(function, events)
    Translator.new(function, events).translate
  end
end
