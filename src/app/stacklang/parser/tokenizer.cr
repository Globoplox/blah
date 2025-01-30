# Split a stream of text into tokens
module Stacklang::Tokenizer
  struct Token
    getter value : String
    getter source : String
    getter line : Int32
    getter character : Int32

    def initialize(@value, @line, @character, @source)
    end
  end

  def self.tokenize(filename : String) : Array(Token)
    source = Path[filename].expend
    File.open filename do |io|
      tokenize io, source: source
    end
  end

  def self.tokenize(io : IO, source : String) : Array(Token)
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
      character += 1

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
        elsif last == '/' && c == '*'
          comment_stack += 1
        end
      elsif last == '/' && c == '*'
        comment_stack += 1
        unless token.size > 1
          tokens << Token.new token[0...-1].join, line_at_start, character_at_start, source if token.size > 1
          token.clear
          line_at_start = line
          character_at_start = character
        end
      elsif c == '\n' || c == ';'
        unless last == '\n'
          transform_last = '\n'
          tokens << Token.new token.join, line_at_start, character_at_start, source unless token.empty?
          tokens << Token.new "\n", line, character, source unless tokens[-1]?.try &.value.== "\n"
          token.clear
          line_at_start = line + 1
          character_at_start = 1
        end
      elsif c == ' ' || c == '\t'
        unless token.empty?
          tokens << Token.new token.join, line_at_start, character_at_start, source unless token.empty?
          token.clear
          line_at_start = line
        end
        character_at_start = character + 1
      elsif c.in? ['[', ']', '{', '}', '(', ')', ':', ',']
        tokens << Token.new token.join, line_at_start, character_at_start, source unless token.empty?
        tokens << Token.new c.to_s, line, character, source
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

        if kind != last_kind || (kind == :operator && !(c.in?(['=', '<', '>', '|']) || (c == '&' && last == '&')))
          tokens << Token.new token.join, line_at_start, character_at_start, source unless token.empty?
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

      if c == '\n'
        character = 0
        line += 1
      end
    end
    tokens << Token.new token.join, line_at_start, character_at_start, source unless token.empty?

    tokens
  end
end
