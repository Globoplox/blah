# Kind of work, unused, to be used with a parser rewrite
# that hopefully will be much better at describing error and context
# TODO: save character and line into tokens
module Stacklang::Lexer
  struct Token
    getter value : String
    getter line : Int32?
    getter character : Int32?
    def initialize(@value, @line, @character)
    end
  end
  
  def self.run(io) : Array(Token)
    tokens = [] of Token
    token = [] of Char
    last = '\0'
    quote = nil
    escaped = false
    comment_stack = 0
    last_kind = nil
    line = 1
    character = 0
    line_at_start = 1
    character_at_start = 1

    io.each_char do |c|
      if c == '\n'
        character = 0
        line += 1
      else 
        character += 1
      end

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
        end
      
      elsif last == '/' && c == '*'
        comment_stack += 1
        unless token.size > 1
          tokens << Token.new token[0...-1].join, line_at_start, character_at_start if token.size > 1
          token.clear
          line_at_start = line
          character_at_start = character
        end

      elsif c == '\n' || c == ';'
        unless last == '\n'
          transform_last = '\n'
          tokens << Token.new token.join, line_at_start, character_at_start unless token.empty?
          tokens << Token.new "\n", line, character unless tokens[-1]?.try &.value.== "\n"
          token.clear
          line_at_start = line
          character_at_start = character
        end

      elsif c == ' ' || c == '\t'
        unless token.empty?
          tokens << Token.new token.join, line_at_start, character_at_start  unless token.empty?
          token.clear
          line_at_start = line
          character_at_start = character
        end
      
      elsif c.in? ['[', ']', '{', '}', '(', ')', ':', ',']
        tokens << Token.new token.join, line_at_start, character_at_start  unless token.empty?
        tokens << Token.new c.to_s, line, character
        token.clear
        line_at_start = line
        character_at_start = character

      
      else

        if c == '"'
          quote = c
        elsif c.alphanumeric? || c == '_'
          kind = :identifier
        else 
          kind = :operator
        end

        if (kind == :operator && last_kind != :operator) || (kind != :operator && last_kind == :operator)
          tokens << Token.new token.join, line_at_start, character_at_start  unless token.empty?
          token.clear
          line_at_start = line
          character_at_start = character

          token << c
        else
          token << c
        end

      last_kind = kind
      end
      last = transform_last || c
    end
    tokens << Token.new token.join, line_at_start, character_at_start  unless token.empty?

    tokens
  end
end