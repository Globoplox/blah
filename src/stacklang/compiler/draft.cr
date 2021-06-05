class Stacklang::Unit

#  class Struct
  #   class Field
  #     def initialize(@name : Identifier, @constraint : Type) end
  #   end
  #   def initialize(@name : String, @fields : Array(Field)) end
  # end

  # class Word < Type end

  # class Pointer < Type
  #   def initialize(@target : Type) end
  # end

  # class Custom < Type
  #   def initialize(@name : String) end
  # end

  
  abstract class Type::Any
    abstract def size : UInt16
  end

  class Type::Word < Type::Any
    getter size = 1u16
  end

  class Type::Pointer < Type::Any
    getter size = 1u16
    def initialize(@pointer_of : Type::Any) end
  end
  
  class Type::Struct
    class Field
      property name
      property any
      property offset
      def initialize(@name : String, @type : Type::Any, @offset : UInt16) end
    end

    property name : String
    property fields : Array(Field)
    @size : UInt16? = nil
    
    def initialize(@ast_struct : AST::Struct)
      @name = ast.name
      @fields = [] of Field
    end

    def solve_constraint(ast : AST::Constraint, types : Hash(String, Type::Any), stack : Array(Type::Any)) : Type::Any 
      case ast
      when AST::Word then Type::Word.new
      when AST::Pointer then Type::Pointer.new solve_constraint ast.target, types, [] of String
      when AST::Custom
        actual_type = types[ast.name]? || raise "Unknown struct name: '{ast.name}'"
        raise "Type #{actual_type.name} is recursive. This is illegal. Use a pointer to #{actual_type.name} instead." if actual_type.in? stack
        actual_type.solve types, stack
        actual_type
      else raise "Unknown Type Kind #{typeof(ast)}"
      end
    end

    def size : UInt16
      @size || raise "Type must be solved before size can be used"
    end
    
    def solve(other_types : Hash(String, Type::Any), stack : Array(Type::Any))
      if @size.nil?
        offset = 0u16
        @fields = @ast_struct.fields.map do |ast_field|
          constraint = solve_field ast_field, other_types, stack + [self]
          Field.new ast_field.name, constraint, (offset += constaint.size) 
        end
        @size = offset
      end
    end
  end
  
  def compile(ast)
    # TYPES:
    # build all, check for name clash
    # then solve all
  end

end







enum GPR
  R1, R2, R3, R4, R5, R6
end

class Register
end

class Variable
  @initialized = false
  @stacked = false # set to true once var has been stacked, even if only once
  @register : Register? = nil
  @offset : Int32
  @name : String? = nil
  @free = false # used to signal currently unused default values
end

class Register
  @variable : Variable?
  @free : Bool
end




class Function
  @return : Nil # must hold the return type if exists but no care rn
  @locs = [] of Loc 
  @compiler : Compiler
    # the compiler is who we ask for spec of stuff
    # that are out of our scope (like other functions that wa need info about
    # to call them)

  def initialize(@ast, @compiler)
    @variables = {} of String => Variable # extract from ast
    @temporaries = [] of Variable # temporary variable, used for storing anonymous return value.
                                  # They can be created on the fly.
                                  # Stacking them should be avoided.
                                  # Referencing them is forbidden (you can't get the address of all rvalues)
    @parameters = {} of String => Variable # extract from ast
    @registers = [] of Register # extract initial state from parameters
    @compiled = false
    @ast = nil # the ast but with all variable declaration removed/replaced
               # by affectation
    @return = nil
  end

  def affect(variable, expression)
    # compute the expression down to a register or a word
    # grab the variable
    # if word, check if fit in 7bit, then add or movi
    # if register, 
    # write the add instruction (add rv, re, r0) to set the thing. 
  end
  
  # ensure that a var is in a register (anyone),
  # can deallocate vars from register into stack unless they use a forbidden reg
  # write the neccessary instruction
  def grab(variable_name, forbidden_registers) : Register
    
  end

  # for a var we can: ask to grab it (link it to a register)
  # ask to stack it (allow to get the offset to stack head)

  def call(call) # a return register or nothing
    # for each param
    # write the value to a temporary variable
    # then grab all of them at the same time in the right order
    # perform the call
    # free all the used temporary vals
    # do not forget to either have some kind of check of tainted registers of to stack variables linked to these before the call / or all variable
    #   and to set as free all the tainted/all registers

    # we wont have the taint list since we can reference external symbols
    # so we will always need to assume all registers must be stacked before calling
    # so we might not need the whole tmp var thing...
    # we don't need to unstack them after the call tho. It will be done by grabbing var if necessary in later code.
    # we return the return value register or nothing if var do have a return value 
  end

  def operator
    # same as call, but for some operators has a predefined inline stuff
    # else mangle the operator and types into a function_name and pass to call.
  end

  def conditional(condition, block, else_block)
    # define name of end and else symbol
    # compute the condition
    # Make a COPY of the current state of @vars and @regs
    # write the beq to else
    # compile the block recursively
    # write the jump to end symbol
    # MAKE ANOTHER COPY of the current state of @vars and regs
    # Restore the COPY of the current state of @vars and regs from the first copy
    # write the else symbol
    # compile the else block recursively
    # write the stop symbol
    # Move vars / registers so they look like the seconds copy (or the opposite)
    #   (find a series of loc that leave regs and vars in the same state, whatever
    #    the previous state).
  end # or maybe just don't do if/else, because handling the several state
  # is annoying af

  def conditional(condition, block)
    # define name of end symbol
    # compute the condition
    # COPY state of vars and regs
    # write the beq to end
    # compile the block recursively
    # move the vars and regs so it looks like the backup
    # define the end symbol
  end

  def loop(condition, block)
    # write start symbol
    # compute the condition
    # COPY state of vars and regs
    # write the beq to end
    # compile the block recursively
    # move the vars and regs so it looks like the backup
    # jmp to start symbol
    # define the end symbol
  end
  
  def compile(toplevel = true)
    # fill the operations by parsing the ast
    
    @compiled = toplevel
  end
end
