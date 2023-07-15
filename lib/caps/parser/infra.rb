# frozen_string_literal: true

require_relative "helpers"

module Caps
  class Parser
    using Caps::Parser::Helpers

    def initialize(tokens)
      @tokens = tokens
      @idx = 0
    end

    def peek
      return nil if @idx >= @tokens.length

      @tokens[@idx]
    end

    def prev
      return @tokens.first if @idx.zero?

      @tokens[@idx - 1]
    end

    def advance
      return nil if peek.nil?

      peek.tap { @idx += 1 }
    end

    def consume_whitespace
      advance while peek.whitespace?
    end

    def tracking
      start = peek.dig(:position, :start)
      result = yield
      finish = prev.dig(:position, :end)
      result.merge({
        position: {
          start: start,
          end: finish
        }
      })
    end

    def syntax_error!(reason)
      token = peek.nil? ? prev : peek
      raise "Syntax Error: #{reason} at line #{token.end_line} " \
            "column #{token.end_column}"
    end
  end
end
