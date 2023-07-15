# frozen_string_literal: true

module Caps
  class Tokenizer
    module Helpers
      refine String do
        def self.helper(name, &block)
          define_method(name, &block)
        end

        helper(:uni) { unpack1("U") }
        helper(:between?) { |a, b| uni >= a && uni <= b }
        helper(:digit?) { between? 0x30, 0x39 }
        helper(:hex?) { digit? || between?(0x41, 0x46) || between?(0x61, 0x66) }
        helper(:uppercase?) { between? 0x41, 0x5a }
        helper(:lowercase?) { between? 0x61, 0x7a }
        helper(:letter?) { uppercase? || lowercase? }

        def non_ascii?
          uni == 0xb7 ||
            between?(0xc0, 0xd6) ||
            between?(0xd8, 0xf6) ||
            between?(0xf8, 0x37d) ||
            between?(0x37f, 0x1fff) ||
            uni == 0x200c ||
            uni == 0x200d ||
            uni == 0x203f ||
            uni == 0x2040 ||
            between?(0x2070, 0x218f) ||
            between?(0x2c00, 0x2fef) ||
            between?(0x3001, 0xd7ff) ||
            between?(0xf900, 0xfdcf) ||
            between?(0xfdf0, 0xfffd) ||
            uni >= 0x10000
        end

        helper(:ident_start?) { letter? || non_ascii? || uni == 0x5f }
        helper(:ident_char?) { ident_start? || digit? || uni == 0x2d }
        helper(:non_printable?) { between?(0x00, 0x08) || uni == 0xb || between?(0xe, 0x1f) || uni == 0x7f }
        helper(:newline?) { uni == 0xa }
        helper(:whitespace?) { newline? || uni == 0x9 || uni == 0x20 }
        helper(:bad_escape?) { newline? }
        helper(:surrogate?) { between?(0xd800, 0xdfff) }
      end

      refine NilClass do
        def self.helper(name, &block)
          define_method(name, &block)
        end

        helper(:uni) { 0x00 }
        helper(:between?) { |_a, _b| false }
        helper(:digit?) { false }
        helper(:hex?) { false }
        helper(:uppercase?) { false }
        helper(:lowercase?) { false }
        helper(:letter?) { false }
        helper(:non_ascii?) { false }
        helper(:ident_start?) { false }
        helper(:ident_char?) { false }
        helper(:non_printable?) { false }
        helper(:newline?) { false }
        helper(:whitespace?) { false }
        helper(:bad_escape?) { false }
        helper(:surrogate?) { false }
      end
    end
  end
end
