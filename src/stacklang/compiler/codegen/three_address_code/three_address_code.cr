require "./codes"
require "./translator"

module Stacklang::ThreeAddressCode

  # Given block of code and the context, produce an array of three address code.
  # *unit* is used to pull type and function definitions,
  # *function* is the optional function being translated and is provided for 
  #   providing additional context in case of error
  # *context* is a mapping of all reachable named address and there type.
  # Usually this mean globals, parameters and variables declared within the block.
  def self.translate(statements, unit, function, context)
    Translator.new(statements, unit, function, context).translate
  end

end
