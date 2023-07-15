# frozen_string_literal: true

require_relative "tokenizer/helpers"
require_relative "tokenizer/location"
require_relative "tokenizer/infra"

module Caps
  class Tokenizer
    using Caps::Tokenizer::Helpers

    LINE_FEED = "\u000a"
    REPLACEMENT_CHARACTER = "\ufffd"
    SOLIDUS = "/"
    REVERSE_SOLIDUS = "\\"
    ASTERISK = "*"
    SINGLE_QUOTE = "'"
    DOUBLE_QUOTE = '"'
    NUMBER_SIGN = "#"
    HYPHEN_MINUS = "\u002d"
    LEFT_PARENS = "("
    RIGHT_PARENS = ")"
    PLUS_SIGN = "+"
    COMMA = ","
    FULL_STOP = "."
    COLON = ":"
    SEMI = ";"
    LESS_THAN = "<"
    COMMERCIAL_AT = "@"
    LEFT_SQUARE = "["
    RIGHT_SQUARE = "]"
    LEFT_CURLY = "{"
    RIGHT_CURLY = "}"
    PERCENTAGE = "%"
    GREATER_THAN = ">"
    EXCLAMATION = "!"

    MAXIMUM_ALLOWED_CODEPOINT = 0x110000

    def push_node(type, **opts)
      @tokens << { type: type }.merge(opts)
    end

    def consume_token
      consume_comment
      return if eof?

      chr = peek
      case
      when chr.whitespace?
        consume_whitespace
      when [SINGLE_QUOTE, DOUBLE_QUOTE].include?(chr)
        consume_string
      when chr == NUMBER_SIGN
        return consume_hash_token if peek1.ident_char? || valid_escape?(offset: 1)

        consume_delim_token

      when chr == LEFT_PARENS
        pack_one(:left_parens)
      when chr == RIGHT_PARENS
        pack_one(:right_parens)
      when chr == COLON
        pack_one(:colon)
      when chr == SEMI
        pack_one(:semicolon)
      when chr == COMMA
        pack_one(:comma)
      when chr == LEFT_SQUARE
        pack_one(:left_square)
      when chr == RIGHT_SQUARE
        pack_one(:right_square)
      when chr == LEFT_CURLY
        pack_one(:left_curly)
      when chr == RIGHT_CURLY
        pack_one(:right_curly)
      when chr == FULL_STOP
        if peek1.digit?
          consume_numeric
        else
          consume_delim_token
        end
      when chr == HYPHEN_MINUS
        if peek1.digit?
          consume_numeric
        elsif peek1 == HYPHEN_MINUS && peek2 == GREATER_THAN
          consume_cdc_token
        elsif ident_sequence_start?
          consume_ident_token
        else
          consume_delim_token
        end
      when chr == LESS_THAN
        is_cdo = isolated do
          advance # consume LESS_THAN
          next_three = [peek, peek1, peek2]
          next_three == [EXCLAMATION, HYPHEN_MINUS, HYPHEN_MINUS]
        end

        if is_cdo
          consume_cdo_token
        else
          consume_delim_token
        end
      when chr == COMMERCIAL_AT
        is_at_keyword = isolated do
          advance # consume COMMERCIAL_AT
          ident_sequence_start?
        end

        loc = mark_pos

        if is_at_keyword
          advance # consume COMMERCIAL_AT
          @tokens << {
            type: :at_keyword,
            value: consume_ident_sequence,
            position: loc.finish
          }
        else
          consume_delim_token
        end

      when chr == REVERSE_SOLIDUS
        if valid_escape?
          consume_ident_token
        else
          loc = mark_pos
          @tokens << {
            type: :delim,
            value: advance,
            position: loc.finish
          }
        end

      when chr.digit?
        consume_numeric

      when chr.ident_start?
        consume_ident_token

      else
        consume_delim_token
      end
    end

    def consume_cdo_token
      loc = mark_pos
      4.times { advance }

      @tokens << {
        type: :cdo,
        position: loc.finish
      }
    end

    def consume_cdc_token
      # the first hyphen has NOT been consumed. Advance three times.
      loc = mark_pos
      3.times { advance }

      @tokens << {
        type: :cdc,
        position: loc.finish
      }
    end

    def consume_ident_token
      loc = mark_pos
      string = consume_ident_sequence
      if string.casecmp?("url") && peek == LEFT_PARENS
        advance # consume LEFT_PARENS
        advance while peek.whitespace? && peek1.whitespace?
        quotes = [DOUBLE_QUOTE, SINGLE_QUOTE]
        if quotes.include?(peek) || (peek1.whitespace? && quotes.include?(peek))
          @tokens << {
            type: :function,
            value: string,
            position: loc.finish
          }
          # next we will have optional whitespace followed by a string, so
          # just create the function token and move on.
        else
          # LEFT_PARENS was already consumed at this point, just consume the
          # url token and get the result.
          consume_url_token(loc)
        end
      elsif peek1 == LEFT_PARENS
        advance
        @tokens << {
          type: :function,
          value: string,
          position: loc.finish
        }
      else
        @tokens << {
          type: :ident,
          value: string,
          position: loc.finish
        }
      end
    end

    def consume_url_token(loc = nil)
      loc ||= mark_pos
      # Consume as much whitespace as possible
      advance while peek.whitespace?
      value = []

      loop do
        chr = peek
        case
        when chr == RIGHT_PARENS
          advance
          break

        when eof?
          break

        when [DOUBLE_QUOTE, SINGLE_QUOTE, LEFT_PARENS].include?(chr), chr.non_printable?
          # Parse error. Consume what's left of the url, return BAD_URL.
          consume_bad_url
          @tokens << {
            type: :bad_url,
            position: loc.finish
          }
          return

        when chr == REVERSE_SOLIDUS
          if valid_escape?
            value << consume_escaped_codepoint
          else
            consume_bad_url
            @tokens << {
              type: :bad_url,
              position: loc.finish
            }
            return
          end

        else
          value << advance
        end
      end

      @tokens << {
        type: :url,
        value: value.join,
        position: loc.finish
      }
    end

    def consume_bad_url
      loop do
        case
        when eof?, peek == RIGHT_PARENS
          return

        when valid_escape?
          consume_escaped_codepoint

        else
          advance
        end
      end
    end

    def consume_whitespace
      pack_while(:whitespace) { peek.whitespace? }
    end

    def consume_comment
      return if peek != SOLIDUS || peek1 != ASTERISK

      loc = mark_pos
      2.times { advance } # Consume '/' and '*'
      comment_data = scoped do
        until eof?
          break if peek == ASTERISK && peek1 == SOLIDUS

          advance
        end
      end

      return if eof? # Malformed sheet?

      2.times { advance } # Consume '*' and '/'

      @tokens << {
        type: :comment,
        value: comment_data.join,
        position: loc.finish
      }
    end

    def consume_string
      loc = mark_pos
      ending_point = advance
      type = :string

      value = scoped do
        until eof?
          break if peek == ending_point

          if peek == LINE_FEED
            # Do not advance. Only create bad-string and stop.
            type = :bad_string
            break
          end

          if peek == REVERSE_SOLIDUS
            advance and return if peek1.nil?

            2.times { advance }
            next
          end

          advance
        end
      end

      advance unless eof? # consume the ending_point left

      @tokens << {
        type: type,
        delimiter: ending_point,
        value: value.join,
        position: loc.finish
      }
    end

    def consume_escaped_codepoint
      # Assumes REVERSE_SOLIDUS was already consumed
      if peek.hex?
        hex = scoped do
          advance

          len = 0
          until eof?
            break unless peek.hex?

            advance
            len += 1
            break if len == 5
          end
        end
        advance if peek.whitespace?
        hex = hex.join.to_i(16)
        uni = [hex].pack("U")
        return REPLACEMENT_CHARACTER if hex.zero? || uni.surrogate? || hex > MAXIMUM_ALLOWED_CODEPOINT

        uni
      elsif eof?
        REPLACEMENT_CHARACTER
      else
        advance
      end
    end

    def consume_ident_sequence
      result = []
      until eof?
        p = peek

        if p.ident_char?
          result << advance
        elsif valid_escape?
          advance
          result << consume_escaped_codepoint
        else
          break
        end
      end

      result.join
    end

    def consume_hash_token
      loc = mark_pos
      advance # consume "#"
      flag = ident_sequence_start? ? :id : nil
      value = consume_ident_sequence
      @tokens << {
        type: :hash,
        literal: @contents[loc.start[:idx]..@idx],
        flag: flag,
        value: value,
        position: loc.finish
      }
    end

    def consume_delim_token
      pack_one(:delim)
    end

    def consume_numeric
      loc = mark_pos
      number = consume_number

      if ident_sequence_start?
        @tokens << {
          type: :dimension,
          value: number[:value],
          flag: number[:type],
          unit: consume_ident_sequence,
          position: loc.finish
        }
      elsif peek == PERCENTAGE
        advance # consume "%"
        @tokens << {
          type: :percentage,
          value: number[:value],
          position: loc.finish
        }
      else
        @tokens << {
          type: :numeric,
          value: number[:value],
          flag: number[:type],
          position: loc.finish
        }
      end
    end

    def consume_number
      type = :integer
      repr = []
      repr << advance if [PLUS_SIGN, HYPHEN_MINUS].include? peek
      repr << advance while peek.digit?

      if peek == FULL_STOP && peek1.digit?
        repr << advance # Consume "."
        repr << advance while peek.digit?
        type = :number
      end

      p = peek
      p1 = peek1
      p2 = peek2
      if %w[E e].include?(p) &&
         (p1.digit? || ([PLUS_SIGN, HYPHEN_MINUS].include?(p1) && p2.digit?))
        type = :number
        repr << advance # consume "e" or "E"
        repr << advance if [PLUS_SIGN, HYPHEN_MINUS].include?(p1) # consume optional sign
        repr << advance while peek.digit?
      end

      repr = repr.join

      {
        type: type,
        value: type == :integer ? repr.to_i : repr.to_f
      }
    end

    def self.stringify(tokens)
      tokens.map do |i|
        objs = [i[:type].to_s, "("]
        objs << i[:value].inspect if i.key? :value
        objs << ")"
        objs.join
      end.join(" ")
    end
  end
end
