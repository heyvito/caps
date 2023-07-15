# frozen_string_literal: true

module Caps
  class Tokenizer
    class Location
      attr_reader :start

      def initialize(parser)
        @parser = parser
        @start = parser.pos
      end

      def push_node(type, **opts)
        @parser.push_node(type, **opts.merge({ position: finish }))
      end

      def finish
        {
          start: @start,
          end: @parser.pos
        }
      end
    end
  end
end
