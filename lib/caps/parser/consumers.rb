# frozen_string_literal: true

module Caps
  class Parser
    module Consumers
      using Caps::Parser::Helpers

      def consume_list_of_rules(top_level: false)
        list = []

        until peek.eof?
          p = peek
          if p.whitespace?
            advance

          elsif (p.cdo? || p.cdc?) && top_level
            advance

          elsif p.cdo? || p.cdc?
            tmp = consume_qualified_rule
            list << tmp unless tmp.nil?

          elsif p.at_keyword?
            list << consume_at_rule

          else
            tmp = consume_qualified_rule
            list << tmp unless tmp.nil?
          end
        end

        list
      end

      def consume_at_rule
        obj = {
          type: :at_rule,
          name: advance,
          prelude: [],
          value: nil
        }

        loop do
          p = peek
          case
          when p.semicolon? || p.eof?
            advance
            return obj

          when p.left_curly?
            obj[:block] = consume_simple_block
            return obj

          else
            obj[:prelude] << consume_component_value
          end
        end
      end

      def consume_qualified_rule
        obj = {
          type: :qualified_rule,
          prelude: [],
          value: nil
        }

        loop do
          p = peek
          case
          when p.eof?
            return nil

          when p.left_curly?
            obj[:block] = consume_simple_block
            return obj

          else
            obj[:prelude] << consume_component_value
          end
        end
      end

      def consume_style_block_contents
        decls = []
        rules = []

        loop do
          p = peek

          case
          when p.whitespace? || p.semicolon?
            advance

          when p.eof?
            return decls + rules

          when p.at_keyword?
            rules << consume_at_rule

          when p.ident?
            tmp = [advance]
            tmp << consume_component_value while !peek.semicolon? && !peek.eof?
            tmp_parser = Parser.new(tmp)
            tmp = tmp_parser.consume_declaration
            decls << tmp unless tmp.nil?

          when p.delim? && p.value == "&"
            tmp = consume_qualified_rule
            rules << tmp unless tmp.nil?

          else
            # Parse error. Throw away until semicolon or eof
            consume_component_value while !peek.semicolon? && !peek.eof?
          end
        end
      end

      def consume_declaration_list
        decls = []

        loop do
          p = peek

          case
          when p.whitespace? || p.semicolon?
            advance

          when p.eof?
            return decls

          when p.at_keyword?
            decls << consume_at_rule

          when p.ident?
            tmp = [advance]
            tmp << consume_component_value while !peek.semicolon? && !peek.eof?
            tmp_parser = Parser.new(tmp)
            tmp = tmp_parser.consume_declaration
            decls << tmp unless tmp.nil?

          else
            # Parse error. Throw away until semicolon or eof
            consume_component_value while !peek.semicolon? || semi.eof?
          end
        end
      end

      def resync_invalid_declaration
        advance until peek.eof? || peek.semicolon?
      end

      def contains_important_annotation?(list)
        last_two = list.reject(&:whitespace?).slice(-2, 2)
        return false unless last_two

        last_two.map(&:type) == %i[delim ident] &&
          last_two.first.value == "!" &&
          last_two.last.value.casecmp?("important")
      end

      def remove_important_annotation(list)
        idx = list.reverse.index do |i|
          i.type == :ident && i.value.casecmp?("important")
        end

        list.slice(0, list.length - idx - 2)
      end

      def consume_declaration
        obj = {
          type: :declaration,
          name: advance,
          value: [],
          important: false
        }

        consume_whitespace

        unless peek.colon?
          resync_invalid_declaration
          return nil
        end

        advance # consume colon

        consume_whitespace

        obj[:value] << consume_component_value until peek.eof? || peek.semicolon?

        if contains_important_annotation?(obj[:value])
          obj[:important] = true
          obj[:value] = remove_important_annotation(obj[:value])
        end

        obj[:value].pop while obj[:value].last.whitespace?

        obj
      end

      def consume_component_value
        if peek.left_curly? || peek.left_square? || peek.left_parens?
          consume_simple_block
        elsif peek.function?
          consume_function
        else
          advance
        end
      end

      def mirror_variant_for(obj)
        case obj.type
        when :left_curly
          :right_curly
        when :left_parens
          :right_parens
        when :left_square
          :right_square
        else
          raise "BUG: No mirror variant for #{obj.type}!"
        end
      end

      def consume_simple_block
        block = {
          type: :simple_block,
          associated_token: advance,
          value: []
        }

        mirror_variant = mirror_variant_for(block[:associated_token])

        loop do
          p = peek
          if p.type == mirror_variant
            advance
            break
          elsif p.eof?
            # parse error
            break
          else
            block[:value] << consume_component_value
          end
        end

        block
      end

      def consume_function
        obj = {
          type: :function,
          name: advance,
          value: []
        }

        loop do
          p = peek
          if p.eof?
            # Parse error
            break
          elsif p.right_parens?
            advance
            break
          else
            obj[:value] << consume_component_value
          end
        end

        obj
      end
    end
  end
end
