class Stacklang::Exception < ::Exception
  def initialize(error, ast = nil, function = nil, cause = nil)
    super String.build { |io|
      io << "Compiler error\n"
      if ast && (token = ast.token)
        source = token.source
        if source
          rel = Path[source].relative_to(Dir.current).to_s
          source = rel if rel.size < source.size
        end
        io << "In #{source}\nAt line #{token.line} column #{token.character}: '#{token.value}'\n"
      end
      if function
        io << "In function #{function.name}\n"
      end
      io << error
    }, cause: cause
  end
end

class Stacklang::InternalError < ::Exception
end
