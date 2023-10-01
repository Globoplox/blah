# Kind of work, unused, to be used with a parser rewrite
# that hopefully will be much better at describing error and context
# TODO: save character and line into tokens
module Lexer
  
  def self.run(io)
    tokens = [] of String
    token = [] of Char
    last = '\0'
    quote = nil
    escaped = false
    comment_stack = 0
    last_kind = nil
    io.each_char do |c|
      transform_last = nil
      kind = nil

      if quote
        token << c
        if escaped
          escaped = false 
        else
          if c == quote
            quote = nil
          elsif c == '\\'
            escaped = true
          end
        end
      
      elsif comment_stack > 0
        if last == '*' && c == '/'
          comment_stack -= 1 
        else
          next
        end
      
      elsif last == '/' && c == '*'
        comment_stack += 1
        unless token.size > 1
          tokens << token[0...-1].join
          token.clear
        end

      elsif c == '\n' || c == ';'
        next if last == ';'
        transform_last = ';'
        tokens << token.join unless token.empty?
        tokens << "\n"
        token.clear

      elsif c == ' ' || c == '\t'
        unless token.empty?
          tokens << token.join unless token.empty?
          token.clear
        end
      
      elsif c.in? ['[', ']', '{', '}', '(', ')', ':']
        tokens << token.join unless token.empty?
        tokens << c.to_s
        token.clear
      
      else

        if c == '"'
          quote = c
        elsif c.alphanumeric? || c == '_'
          kind = :identifier
        else 
          kind = :operator
        end

        if (kind == :operator && last_kind != :operator) || (kind != :operator && last_kind == :operator)
          tokens << token.join unless token.empty?
          token.clear
          token << c
        else
          token << c
        end

      last_kind = kind
      end
      last = transform_last || c
    end
    tokens
  end
end

File.open "examples/brainfuck/brainfuck.sl" do |file|
  puts Lexer.run(file).join ' '
end