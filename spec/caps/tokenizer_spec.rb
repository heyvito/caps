# frozen_string_literal: true

RSpec.describe Caps::Tokenizer do
  describe "preprocesses input stream" do
    # Replace any U+000D CARRIAGE RETURN (CR) code points, U+000C FORM FEED (FF)
    # code points, or pairs of U+000D CARRIAGE RETURN (CR) followed by U+000A
    # LINE FEED (LF) in input by a single U+000A LINE FEED (LF) code point.

    examples = {
      "a\u000db" => "a\u000ab",
      "a\u000cb" => "a\u000ab",
      "a\u000d\u000ab" => "a\u000ab",
      "a\u000d\u000a\u000d\u000ab" => "a\u000a\u000ab"
    }

    examples.each do |k, v|
      it "correctly preprocesses #{k.inspect} into #{v.inspect}" do
        tok = described_class.new(k)
        expect(tok.contents).to eq v.chars
      end
    end
  end

  describe "comments" do
    it "parses comments" do
      tokens = described_class.parse("/* This is a test! */")
      expect(tokens.length).to eq 1
      expect(tokens.first).to eq({
        type: :comment,
        value: " This is a test! ",
        position: {
          start: { idx: 0, line: 1, column: 1 },
          end: { idx: 21, line: 1, column: 21 }
        }
      })
    end
  end

  describe "whitespaces" do
    it "parses whitespaces" do
      tokens = described_class.parse("    \t\t\n")
      expect(tokens.length).to eq 1
      expect(tokens.first).to eq({
        type: :whitespace,
        value: "    \t\t\n",
        position: {
          start: { idx: 0, line: 1, column: 1 },
          end: { idx: 7, line: 2, column: 1 }
        }
      })
    end
  end

  describe "strings" do
    it "parses single-quoted strings" do
      tokens = described_class.parse("'caps'")
      expect(tokens.length).to eq 1
      expect(tokens.first).to eq({
        type: :string,
        delimiter: "'",
        value: "caps",
        position: {
          start: { idx: 0, line: 1, column: 1 },
          end: { idx: 6, line: 1, column: 6 }
        }
      })
    end

    it "parses double-quoted strings" do
      tokens = described_class.parse('"caps"')
      expect(tokens.length).to eq 1
      expect(tokens.first).to eq({
        type: :string,
        delimiter: '"',
        value: "caps",
        position: {
          start: { idx: 0, line: 1, column: 1 },
          end: { idx: 6, line: 1, column: 6 }
        }
      })
    end

    it "handles eof errors" do
      tokens = described_class.parse("'caps")
      expect(tokens.length).to eq 1
      expect(tokens.first).to eq({
        type: :string,
        delimiter: "'",
        value: "caps",
        position: {
          start: { idx: 0, line: 1, column: 1 },
          end: { idx: 5, line: 1, column: 5 }
        }
      })
    end

    it "handles escapes before eof" do
      tokens = described_class.parse("'caps\\")
      expect(tokens).to be_empty
    end

    it "handles newline errors" do
      tokens = described_class.parse("'caps\ncaps'")
      expect(tokens).not_to be_empty
      expect(tokens.map { |i| i[:type] }).to eq %i[bad_string ident string]
    end

    it "handles escaped ending code point" do
      tokens = described_class.parse("'caps\\'caps'")
      expect(tokens.length).to eq 1
      expect(tokens.first).to eq({
        type: :string,
        delimiter: "'",
        value: "caps\\'caps",
        position: {
          start: { idx: 0, line: 1, column: 1 },
          end: { idx: 12, line: 1, column: 12 }
        }
      })
    end

    it "handles escaped newlines" do
      tokens = described_class.parse("'caps\\\ncaps'")
      expect(tokens.length).to eq 1
      expect(tokens.first).to eq({
        type: :string,
        delimiter: "'",
        value: "caps\\\ncaps",
        position: {
          start: { idx: 0, line: 1, column: 1 },
          end: { idx: 12, line: 2, column: 6 }
        }
      })
    end
  end

  describe "hash tokens" do
    it "returns a delim in case it makes no sense" do
      tokens = described_class.parse("#/**/")
      expect(tokens.first[:type]).to eq :delim
      expect(tokens.first[:value]).to eq "#"
      expect(tokens.first[:flag]).to be_nil
    end

    it "returns a non-id if the identifier contains unexpected characters" do
      tokens = described_class.parse("#1234")
      expect(tokens.first[:type]).to eq :hash
      expect(tokens.first[:value]).to eq "1234"
      expect(tokens.first[:flag]).to be_nil
    end

    it "returns an id hash" do
      tokens = described_class.parse("#a-pretty-id")
      expect(tokens.first[:type]).to eq :hash
      expect(tokens.first[:value]).to eq "a-pretty-id"
      expect(tokens.first[:flag]).to eq :id
    end
  end

  describe "single tokens" do
    expected = {
      left_parens: "(",
      right_parens: ")",
      colon: ":",
      semicolon: ";",
      comma: ",",
      left_square: "[",
      right_square: "]",
      left_curly: "{",
      right_curly: "}"
    }

    expected.each_entry do |k, v|
      it "parses #{v.inspect}" do
        tokens = described_class.parse(v)
        expect(tokens.first[:type]).to eq k
      end
    end
  end

  describe "full stop" do
    it "parses a number" do
      tokens = described_class.parse(".1234")
      expect(tokens.length).to eq 1
      expect(tokens.first[:type]).to eq :numeric
      expect(tokens.first[:value]).to eq 0.1234
      expect(tokens.first[:flag]).to eq :number
      expect(tokens.first[:position]).to eq({ start: { idx: 0, line: 1, column: 1 },
                                              end: { idx: 5, line: 1, column: 5 } })
    end

    it "parses a number in scientific notation" do
      tokens = described_class.parse(".1e2")
      expect(tokens.first[:value]).to eq 10.0
    end

    it "parses a percentage" do
      tokens = described_class.parse(".1%")
      expect(tokens.length).to eq 1
      per = tokens.first
      expect(per[:type]).to eq :percentage
      expect(per[:value]).to eq 0.1
    end

    it "parses a number with unit" do
      tokens = described_class.parse(".1\\0070x")
      expect(tokens.length).to eq 1
      uni = tokens.first
      expect(uni[:type]).to eq :dimension
      expect(uni[:value]).to eq 0.1
      expect(uni[:flag]).to eq :number
      expect(uni[:unit]).to eq "px"
    end

    it "parses a dot followed by identifier" do
      tokens = described_class.parse(".foo")
      expect(tokens.map { |i| i[:type] }).to eq %i[delim ident]
    end
  end

  describe "hyphen minus" do
    it "parses a number" do
      tokens = described_class.parse("-100")
      tokens.first
      expect(tokens.first).to eq({
        type: :numeric,
        value: -100,
        flag: :integer,
        position: {
          start: {
            idx: 0,
            line: 1,
            column: 1
          },
          end: {
            idx: 4,
            line: 1,
            column: 4
          }
        }
      })
    end

    it "parses a cdc" do
      tokens = described_class.parse("-->")
      expect(tokens.first).to eq({
        type: :cdc,
        position: {
          start: {
            idx: 0,
            line: 1,
            column: 1
          },
          end: {
            idx: 3,
            line: 1,
            column: 3
          }
        }
      })
    end

    it "parses an ident token" do
      tokens = described_class.parse("-foobar")
      expect(tokens.first).to eq({
        type: :ident,
        value: "-foobar",
        position: {
          start: {
            idx: 0,
            line: 1,
            column: 1
          },
          end: {
            idx: 7,
            line: 1,
            column: 7
          }
        }
      })
    end

    it "parses a delimiter" do
      tokens = described_class.parse("-")
      expect(tokens.first).to eq({
        type: :delim,
        value: "-",
        position: {
          start: { idx: 0, line: 1, column: 1 },
          end: { idx: 1, line: 1, column: 1 }
        }
      })
    end
  end

  describe "less than" do
    it "parses a CDO token" do
      tokens = described_class.parse("<!--")
      expect(tokens.first).to eq({
        type: :cdo,
        position: {
          start: { idx: 0, line: 1, column: 1 },
          end: { idx: 4, line: 1, column: 4 }
        }
      })
    end

    it "parses a less than delim" do
      tokens = described_class.parse("<")
      expect(tokens.first).to eq({
        type: :delim,
        value: "<",
        position: {
          start: { idx: 0, line: 1, column: 1 },
          end: { idx: 1, line: 1, column: 1 }
        }
      })
    end
  end

  describe "commercial at" do
    it "parses an at-keyword" do
      tokens = described_class.parse("@caps")
      expect(tokens.first).to eq({
        type: :at_keyword,
        value: "caps",
        position: {
          start: { idx: 0, line: 1, column: 1 },
          end: { idx: 5, line: 1, column: 5 }
        }
      })
    end

    it "parses an commercial at delim" do
      tokens = described_class.parse("@")
      expect(tokens.first).to eq({
        type: :delim,
        value: "@",
        position: {
          start: { idx: 0, line: 1, column: 1 },
          end: { idx: 1, line: 1, column: 1 }
        }
      })
    end
  end

  describe "reverse solidus" do
    it "parses an escape as an ident" do
      tokens = described_class.parse("\\0048 ello")
      expect(tokens.first).to eq({
        type: :ident,
        value: "Hello",
        position: {
          start: { idx: 0, line: 1, column: 1 },
          end: { idx: 10, line: 1, column: 10 }
        }
      })
    end

    it "handles invalid escapes" do
      tokens = described_class.parse("\\\nZ")
      expect(tokens.length).to eq 3
      expect(tokens.map { |i| i[:type] }).to eq %i[delim whitespace ident]
    end
  end

  describe "numbers" do
    it "parse a number" do
      tokens = described_class.parse("10")
      expect(tokens.first).to eq({
        type: :numeric,
        value: 10,
        flag: :integer,
        position: {
          start: { idx: 0, line: 1, column: 1 },
          end: { idx: 2, line: 1, column: 2 }
        }
      })
    end
  end

  describe "url" do
    it "parses an url without quotes" do
      tokens = described_class.parse("url(https://vito.io)")
      expect(tokens.length).to eq 1
      expect(tokens.first).to eq({
        type: :url,
        value: "https://vito.io",
        position: {
          start: { idx: 0, line: 1, column: 1 },
          end: { idx: 20, line: 1, column: 20 }
        }
      })
    end

    it "parses an url with quotes" do
      tokens = described_class.parse("url('test')")
      expect(tokens.length).to eq 3
      expect(tokens.first).to eq({
        type: :function,
        value: "url",
        position: {
          start: { idx: 0, line: 1, column: 1 },
          end: { idx: 4, line: 1, column: 5 }
        }
      })
      expect(tokens[1]).to eq({
        type: :string,
        delimiter: "'",
        value: "test",
        position: {
          start: { idx: 4, line: 1, column: 5 },
          end: { idx: 10, line: 1, column: 11 }
        }
      })
      expect(tokens[2]).to eq({
        type: :right_parens,
        value: ")",
        position: {
          start: { idx: 10, line: 1, column: 11 },
          end: { idx: 11, line: 1, column: 11 }
        }
      })
    end

    it "parses a bad url" do
      tokens = described_class.parse("url(foo'bar)")
      expect(tokens.length).to eq 2
      expect(tokens.first).to eq({
        type: :bad_url,
        position: {
          start: { idx: 0, line: 1, column: 1 },
          end: { idx: 11, line: 1, column: 12 }
        }
      })
      expect(tokens[1]).to eq({
        type: :right_parens,
        value: ")",
        position: {
          start: { idx: 11, line: 1, column: 12 },
          end: { idx: 12, line: 1, column: 12 }
        }
      })
    end
  end

  describe "tokenize real css" do
    it "tokenizes css from vito.io" do
      data = fixture_data("vito.io.css")
      tokens = described_class.parse(data)
      expect(tokens.length).to eq 5111
    end
  end
end
