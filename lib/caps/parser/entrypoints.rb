# frozen_string_literal: true

module Caps
  class Parser
    module Entrypoints
      using Caps::Parser::Helpers

      def parse_full_sheet
        base = parse_stylesheet
        base[:value].map! do |obj|
          if obj[:type] == :qualified_rule
            p = Parser.new(obj.dig(:block, :value))
            obj[:block][:value] = p.parse_style_block_contents
          elsif obj[:type] == :at_rule && obj.dig(:name, :value).downcase == "font-face"
            p = Parser.new(obj.dig(:block, :value))
            obj[:block][:value] = p.parse_declaration_list
          end
          obj
        end

        base
      end

      def parse_stylesheet(location: nil)
        {
          type: :stylesheet,
          location: location,
          value: consume_list_of_rules(top_level: true)
        }
      end

      def parse_rule_list
        consume_list_of_rules(top_level: false)
      end

      def parse_rule
        consume_whitespace
        val = peek
        if val.eof?
          # EOF. Raise syntax error.
          syntax_error! "Unexpected EOF"
        end

        ret_val = if val.at_rule?
          consume_at_rule
        else
          consume_qualified_rule
        end

        consume_whitespace

        syntax_error! "Expected EOF, found #{peek.type} instead" unless peek.eof?

        ret_val
      end

      def parse_declaration
        consume_whitespace
        syntax_error! "Unexpected #{peek.type}, expected ident" unless peek.ident?

        consume_declaration.tap do |decl|
          syntax_error! "Expected declaration to be consumed" if decl.nil?
        end
      end

      def parse_style_block_contents
        consume_style_block_contents
      end

      def parse_declaration_list
        consume_declaration_list
      end

      def parse_component_value
        consume_whitespace
        syntax_error! "Unexpected EOF" if peek.eof?

        ret_val = consume_component_value
        consume_whitespace
        return ret_val if peek.eof?

        syntax_error! "Expected EOF"
      end

      def parse_component_value_list
        arr = []
        loop do
          obj = consume_component_value
          break if obj.eof?

          arr << obj
        end
        arr
      end

      def parse_comma_separated_component_values
        cvls = []

        loop do
          cv = consume_component_value
          if cv.comma?
            next
          elsif cv.eof?
            break
          end

          cvls << cv
        end

        cvls
      end
    end
  end
end
