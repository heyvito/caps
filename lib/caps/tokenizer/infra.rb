# frozen_string_literal: true

module Caps
  class Tokenizer
    using Caps::Tokenizer::Helpers
    attr_accessor :contents, :tokens

    def self.parse(src)
      new(src).parse!
    end

    def initialize(contents)
      @contents = self.class.preprocess(contents)
      setup
    end

    def parse!
      consume_token until eof?
      @tokens
    end

    def pos
      { idx: @idx, line: @line, column: @column }
    end

    def self.preprocess(contents)
      codepoints = []
      clusters = contents.grapheme_clusters
      i = 0
      until i == clusters.length
        code = clusters[i]

        if code.uni == 0x0d && clusters[i + 1].uni == 0x0a
          codepoints << LINE_FEED
          i += 1
          next
        end

        code = LINE_FEED if code.uni == 0x0d || code.uni == 0x0c

        code = REPLACEMENT_CHARACTER if code.between?(0xd800, 0xdbff) || code.between?(0xdc00, 0xdfff) || code.uni.zero?

        codepoints << code
        i += 1
      end

      codepoints
    end

    def setup
      @idx = 0
      @len = @contents.length
      @line = 1
      @column = 1
      @last_line_length = 0
      @tokens = []
    end

    def eof?
      @idx >= @contents.length
    end

    def peek(qty = 0)
      return nil if @idx + qty >= @len

      @contents[@idx + qty]
    end

    def peek1
      peek(1)
    end

    def peek2
      peek(2)
    end

    def advance
      chr = @contents[@idx]
      @idx += 1
      if @idx > @len
        backtrace = Thread.current.backtrace.reject do |v|
          v.start_with?("/opt") || v.start_with?("/usr")
        end.join("\n")
        raise "[BUG] Over-read! @idx=#{@idx} @len=#{@len} #advance without #peek or #eof?\n#{backtrace}"
      end

      return chr if eof?

      if @contents[@idx].newline?
        @line += 1
        @last_line_length = @column
        @column = 1
      else
        @column += 1
      end

      chr
    end

    def scoped
      start = @idx
      yield
      @contents[start...@idx]
    end

    def isolated
      old = pos
      begin
        yield
      ensure
        @idx = old[:idx]
        @line = old[:line]
        @column = old[:column]
      end
    end

    def mark_pos
      Location.new(self)
    end

    def pack_while(type)
      start = mark_pos
      data = scoped do
        loop do
          break if !yield || eof?

          advance
        end
      end

      start.push_node(type, value: data.join)
    end

    def pack_one(type)
      pack = true
      pack_while(type) { pack.tap { pack = !pack } }
    end

    def valid_escape?(offset: 0)
      check = -> { peek == REVERSE_SOLIDUS && peek1 != LINE_FEED }
      if offset.positive?
        isolated do
          offset.times { advance }
          check.call
        end
      else
        check.call
      end
    end

    def ident_sequence_start?
      case peek
      when HYPHEN_MINUS
        (peek1.ident_start? || peek1 == HYPHEN_MINUS) || valid_escape?(offset: 1)
      when REVERSE_SOLIDUS
        valid_escape?
      else
        peek.ident_start?
      end
    end
  end
end
