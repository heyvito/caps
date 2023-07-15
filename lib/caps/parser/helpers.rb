# frozen_string_literal: true

module Caps
  class Parser
    module Helpers
      refine Hash do
        def self.helper(name, &block)
          define_method(name, &block)
        end

        def self.tassert(tname)
          helper("#{tname}?".to_sym) { type == tname }
        end

        def start_line
          dig(:position, :start, :line)
        end

        def start_column
          dig(:position, :start, :column)
        end

        def end_column
          dig(:position, :end, :column)
        end

        def end_line
          dig(:position, :end, :line)
        end

        def type
          self[:type]
        end

        def value
          self[:value]
        end

        tassert(:eof)
        tassert(:ident)
        tassert(:whitespace)
        tassert(:at_keyword)
        tassert(:comma)
        tassert(:semicolon)
        tassert(:left_curly)
        tassert(:delim)
        tassert(:colon)
        tassert(:bang)
        tassert(:left_square)
        tassert(:right_square)
        tassert(:left_parens)
        tassert(:right_parens)
        tassert(:function)
        tassert(:at_rule)
        tassert(:cdo)
        tassert(:cdc)
      end

      refine NilClass do
        def self.helper(name, &block)
          define_method(name, &block)
        end

        def self.tassert(tname)
          helper("#{tname}?") { false }
        end

        def type
          :eof
        end

        def eof?
          true
        end

        tassert(:ident)
        tassert(:whitespace)
        tassert(:at_keyword)
        tassert(:comma)
        tassert(:semicolon)
        tassert(:left_curly)
        tassert(:delim)
        tassert(:colon)
        tassert(:bang)
        tassert(:left_square)
        tassert(:right_square)
        tassert(:left_parens)
        tassert(:right_square)
        tassert(:function)
        tassert(:at_rule)
        tassert(:cdo)
        tassert(:cdc)
      end
    end
  end
end
