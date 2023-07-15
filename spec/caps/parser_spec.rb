# frozen_string_literal: true

RSpec.describe Caps::Parser do
  parser_for = ->(data) { Caps::Parser.new(Caps::Tokenizer.parse(data)) }

  describe "entrypoints" do
    describe "#parse_comma_separated_component_values" do
      it "parses a comma-separated list" do
        input = "test1, test2, test3, 4"
        tokens = Caps::Tokenizer.parse(input)
        parser = Caps::Parser.new(tokens)
        ast = parser.parse_comma_separated_component_values
        expected = %i[
          ident whitespace
          ident whitespace
          ident whitespace
          numeric
        ]
        expect(ast.map { |i| i[:type] }).to eq expected
      end
    end

    describe "#parse_component_value_list" do
      it "parses a component value list" do
        input = "test1 test2 test3 4"
        parser = parser_for.call(input)
        ast = parser.parse_component_value_list
        expected = %i[
          ident whitespace
          ident whitespace
          ident whitespace
          numeric
        ]
        expect(ast.map { |i| i[:type] }).to eq expected
      end
    end

    describe "#parse_component_value" do
      it "parses a component value" do
        input = "   \ttest\t    "
        parser = parser_for.call(input)
        ast = parser.parse_component_value
        expect(ast[:type]).to eq :ident
        expect(ast[:value]).to eq "test"
      end
    end

    describe "#parse_declaration" do
      it "parses a multi-value declaration" do
        parser = parser_for.call("font-family: system-mono, monospaced")
        ast = parser.parse_declaration
        expect(ast.dig(:name, :value)).to eq "font-family"
        expect(ast[:value].length).to eq 4
        expect(ast[:value].map { |i| i[:type] }).to eq %i[
          ident comma whitespace ident
        ]
      end

      it "parses a declaration with a single value" do
        parser = parser_for.call("font-family: system-mono")
        ast = parser.parse_declaration
        expect(ast[:type]).to eq :declaration
        expect(ast.dig(:name, :value)).to eq "font-family"
        expect(ast[:value].length).to eq 1
        expect(ast.dig(:value, 0, :value)).to eq "system-mono"
        expect(ast[:important]).to be false
      end

      it "parses an important declaration" do
        parser = parser_for.call("font-family: system-mono !important ")
        ast = parser.parse_declaration
        expect(ast[:important]).to be true
        expect(ast[:value].length).to eq 1
      end
    end

    describe "#parse_delcaration_list" do
      it "parses a list" do
        input = <<-CSS
          test1: true;
          test2: true;
          test3: false;
        CSS
        parser = parser_for.call(input)
        ast = parser.parse_declaration_list
        expect(ast.length).to eq 3
        expect(ast[0]).to be_a_declaration("test1", [
                                             { type: :ident, value: "true" }
                                           ])
        expect(ast[1]).to be_a_declaration("test2", [
                                             { type: :ident, value: "true" }
                                           ])
        expect(ast[2]).to be_a_declaration("test3", [
                                             { type: :ident, value: "false" }
                                           ])
      end
    end

    describe "#parse_style_block_contents" do
      it "parses block contents" do
        parser = parser_for.call(<<-CSS)
          font-family: monospaced, sans-serif;
          font-size: 17px;
          background-image: url(/foo.png);
        CSS

        ast = parser.parse_style_block_contents
        expect(ast).to eq([
                            {
                              type: :declaration,
                              name: {
                                type: :ident,
                                value: "font-family",
                                position: {
                                  start: { idx: 10, line: 1, column: 11 },
                                  end: { idx: 21, line: 1, column: 22 }
                                }
                              },
                              value: [
                                {
                                  type: :ident,
                                  value: "monospaced",
                                  position: {
                                    start: { idx: 23, line: 1, column: 24 },
                                    end: { idx: 33, line: 1, column: 34 }
                                  }
                                },
                                {
                                  type: :comma,
                                  value: ",",
                                  position: {
                                    start: { idx: 33, line: 1, column: 34 },
                                    end: { idx: 34, line: 1, column: 35 }
                                  }
                                },
                                {
                                  type: :whitespace,
                                  value: " ",
                                  position: {
                                    start: { idx: 34, line: 1, column: 35 },
                                    end: { idx: 35, line: 1, column: 36 }
                                  }
                                },
                                {
                                  type: :ident,
                                  value: "sans-serif",
                                  position: {
                                    start: { idx: 35, line: 1, column: 36 },
                                    end: { idx: 45, line: 1, column: 46 }
                                  }
                                }
                              ],
                              important: false
                            },
                            {
                              type: :declaration,
                              name: {
                                type: :ident,
                                value: "font-size",
                                position: {
                                  start: { idx: 57, line: 2, column: 12 },
                                  end: { idx: 66, line: 2, column: 21 }
                                }
                              },
                              value: [
                                {
                                  type: :dimension,
                                  value: 17,
                                  flag: :integer,
                                  unit: "px",
                                  position: {
                                    start: { idx: 68, line: 2, column: 23 },
                                    end: { idx: 72, line: 2, column: 27 }
                                  }
                                }
                              ],
                              important: false
                            },
                            {
                              type: :declaration,
                              name: {
                                type: :ident,
                                value: "background-image",
                                position: {
                                  start: { idx: 84, line: 3, column: 12 },
                                  end: { idx: 100, line: 3, column: 28 }
                                }
                              },
                              value: [
                                {
                                  type: :url,
                                  value: "/foo.png",
                                  position: {
                                    start: { idx: 102, line: 3, column: 30 },
                                    end: { idx: 115, line: 3, column: 43 }
                                  }
                                }
                              ],
                              important: false
                            }
                          ])
      end
    end

    describe "#parse_declaration" do
      it "parses a declaration" do
        parser = parser_for.call("font-size: 90px")
        ast = parser.parse_declaration
        expect(ast).to eq({
          type: :declaration,
          name: {
            type: :ident,
            value: "font-size",
            position: {
              start: { idx: 0, line: 1, column: 1 },
              end: { idx: 9, line: 1, column: 10 }
            }
          },
          value: [
            {
              type: :dimension,
              value: 90,
              flag: :integer,
              unit: "px",
              position: {
                start: { idx: 11, line: 1, column: 12 },
                end: { idx: 15, line: 1, column: 15 }
              }
            }
          ],
          important: false
        })
      end
    end

    describe "#parse_rule" do
      it "parses a rule" do
        input = "p { font-size: 90px }"
        ast = parser_for.call(input).parse_rule
        expect(ast).to eq({
          type: :qualified_rule,
          prelude: [
            {
              type: :ident,
              value: "p",
              position: {
                start: { idx: 0, line: 1, column: 1 },
                end: { idx: 1, line: 1, column: 2 }
              }
            },
            {
              type: :whitespace,
              value: " ",
              position: {
                start: { idx: 1, line: 1, column: 2 },
                end: { idx: 2, line: 1, column: 3 }
              }
            }
          ],
          value: nil,
          block: {
            type: :simple_block,
            associated_token: {
              type: :left_curly,
              value: "{",
              position: {
                start: { idx: 2, line: 1, column: 3 },
                end: { idx: 3, line: 1, column: 4 }
              }
            },
            value: [
              {
                type: :whitespace,
                value: " ",
                position: {
                  start: { idx: 3, line: 1, column: 4 },
                  end: { idx: 4, line: 1, column: 5 }
                }
              },
              {
                type: :ident,
                value: "font-size",
                position: {
                  start: { idx: 4, line: 1, column: 5 },
                  end: { idx: 13, line: 1, column: 14 }
                }
              },
              {
                type: :colon,
                value: ":",
                position: {
                  start: { idx: 13, line: 1, column: 14 },
                  end: { idx: 14, line: 1, column: 15 }
                }
              },
              {
                type: :whitespace,
                value: " ",
                position: {
                  start: { idx: 14, line: 1, column: 15 },
                  end: { idx: 15, line: 1, column: 16 }
                }
              },
              {
                type: :dimension,
                value: 90,
                flag: :integer,
                unit: "px",
                position: {
                  start: { idx: 15, line: 1, column: 16 },
                  end: { idx: 19, line: 1, column: 20 }
                }
              },
              {
                type: :whitespace,
                value: " ",
                position: {
                  start: { idx: 19, line: 1, column: 20 },
                  end: { idx: 20, line: 1, column: 21 }
                }
              }
            ]
          }
        })
      end
    end

    describe "#parse_rule_list" do
      it "parses a list of rules" do
        parser = parser_for.call(<<-CSS)
          p { color: red; }
          h1 { font-weight: 400; }
        CSS
        ast = parser.parse_rule_list
        expect(ast).to eq([
                            {
                              type: :qualified_rule,
                              prelude: [
                                {
                                  type: :ident,
                                  value: "p",
                                  position: {
                                    start: { idx: 10, line: 1, column: 11 },
                                    end: { idx: 11, line: 1, column: 12 }
                                  }
                                },
                                {
                                  type: :whitespace,
                                  value: " ",
                                  position: {
                                    start: { idx: 11, line: 1, column: 12 },
                                    end: { idx: 12, line: 1, column: 13 }
                                  }
                                }
                              ],
                              value: nil,
                              block: {
                                type: :simple_block,
                                associated_token: {
                                  type: :left_curly,
                                  value: "{",
                                  position: {
                                    start: { idx: 12, line: 1, column: 13 },
                                    end: { idx: 13, line: 1, column: 14 }
                                  }
                                },
                                value: [
                                  {
                                    type: :whitespace,
                                    value: " ",
                                    position: {
                                      start: { idx: 13, line: 1, column: 14 },
                                      end: { idx: 14, line: 1, column: 15 }
                                    }
                                  },
                                  {
                                    type: :ident,
                                    value: "color",
                                    position: {
                                      start: { idx: 14, line: 1, column: 15 },
                                      end: { idx: 19, line: 1, column: 20 }
                                    }
                                  },
                                  {
                                    type: :colon,
                                    value: ":",
                                    position: {
                                      start: { idx: 19, line: 1, column: 20 },
                                      end: { idx: 20, line: 1, column: 21 }
                                    }
                                  },
                                  {
                                    type: :whitespace,
                                    value: " ",
                                    position: {
                                      start: { idx: 20, line: 1, column: 21 },
                                      end: { idx: 21, line: 1, column: 22 }
                                    }
                                  },
                                  {
                                    type: :ident,
                                    value: "red",
                                    position: {
                                      start: { idx: 21, line: 1, column: 22 },
                                      end: { idx: 24, line: 1, column: 25 }
                                    }
                                  },
                                  {
                                    type: :semicolon,
                                    value: ";",
                                    position: {
                                      start: { idx: 24, line: 1, column: 25 },
                                      end: { idx: 25, line: 1, column: 26 }
                                    }
                                  },
                                  {
                                    type: :whitespace,
                                    value: " ",
                                    position: {
                                      start: { idx: 25, line: 1, column: 26 },
                                      end: { idx: 26, line: 1, column: 27 }
                                    }
                                  }
                                ]
                              }
                            },
                            {
                              type: :qualified_rule,
                              prelude: [
                                {
                                  type: :ident,
                                  value: "h1",
                                  position: {
                                    start: { idx: 38, line: 2, column: 12 },
                                    end: { idx: 40, line: 2, column: 14 }
                                  }
                                },
                                {
                                  type: :whitespace,
                                  value: " ",
                                  position: {
                                    start: { idx: 40, line: 2, column: 14 },
                                    end: { idx: 41, line: 2, column: 15 }
                                  }
                                }
                              ],
                              value: nil,
                              block: {
                                type: :simple_block,
                                associated_token: {
                                  type: :left_curly,
                                  value: "{",
                                  position: {
                                    start: { idx: 41, line: 2, column: 15 },
                                    end: { idx: 42, line: 2, column: 16 }
                                  }
                                },
                                value: [
                                  {
                                    type: :whitespace,
                                    value: " ",
                                    position: {
                                      start: { idx: 42, line: 2, column: 16 },
                                      end: { idx: 43, line: 2, column: 17 }
                                    }
                                  },
                                  {
                                    type: :ident,
                                    value: "font-weight",
                                    position: {
                                      start: { idx: 43, line: 2, column: 17 },
                                      end: { idx: 54, line: 2, column: 28 }
                                    }
                                  },
                                  {
                                    type: :colon,
                                    value: ":",
                                    position: {
                                      start: { idx: 54, line: 2, column: 28 },
                                      end: { idx: 55, line: 2, column: 29 }
                                    }
                                  },
                                  {
                                    type: :whitespace,
                                    value: " ",
                                    position: {
                                      start: { idx: 55, line: 2, column: 29 },
                                      end: { idx: 56, line: 2, column: 30 }
                                    }
                                  },
                                  {
                                    type: :numeric,
                                    value: 400,
                                    flag: :integer,
                                    position: {
                                      start: { idx: 56, line: 2, column: 30 },
                                      end: { idx: 59, line: 2, column: 33 }
                                    }
                                  },
                                  {
                                    type: :semicolon,
                                    value: ";",
                                    position: {
                                      start: { idx: 59, line: 2, column: 33 },
                                      end: { idx: 60, line: 2, column: 34 }
                                    }
                                  },
                                  {
                                    type: :whitespace,
                                    value: " ",
                                    position: {
                                      start: { idx: 60, line: 2, column: 34 },
                                      end: { idx: 61, line: 2, column: 35 }
                                    }
                                  }
                                ]
                              }
                            }
                          ])
      end
    end

    describe "#parse_stylesheet" do
      it "parses a stylesheet" do
        ast = parser_for.call(<<-CSS).parse_stylesheet
          .foo { color: black }
          .test { font-size: 17px; }
        CSS
        expect(ast).to eq({
          type: :stylesheet,
          location: nil,
          value: [
            {
              type: :qualified_rule,
              prelude: [
                {
                  type: :delim,
                  value: ".",
                  position: {
                    start: { idx: 10, line: 1, column: 11 },
                    end: { idx: 11, line: 1, column: 12 }
                  }
                },
                {
                  type: :ident,
                  value: "foo",
                  position: {
                    start: { idx: 11, line: 1, column: 12 },
                    end: { idx: 14, line: 1, column: 15 }
                  }
                },
                {
                  type: :whitespace,
                  value: " ",
                  position: {
                    start: { idx: 14, line: 1, column: 15 },
                    end: { idx: 15, line: 1, column: 16 }
                  }
                }
              ],
              value: nil,
              block: {
                type: :simple_block,
                associated_token: {
                  type: :left_curly,
                  value: "{",
                  position: {
                    start: { idx: 15, line: 1, column: 16 },
                    end: { idx: 16, line: 1, column: 17 }
                  }
                },
                value: [
                  {
                    type: :whitespace,
                    value: " ",
                    position: {
                      start: { idx: 16, line: 1, column: 17 },
                      end: { idx: 17, line: 1, column: 18 }
                    }
                  },
                  {
                    type: :ident,
                    value: "color",
                    position: {
                      start: { idx: 17, line: 1, column: 18 },
                      end: { idx: 22, line: 1, column: 23 }
                    }
                  },
                  {
                    type: :colon,
                    value: ":",
                    position: {
                      start: { idx: 22, line: 1, column: 23 },
                      end: { idx: 23, line: 1, column: 24 }
                    }
                  },
                  {
                    type: :whitespace,
                    value: " ",
                    position: {
                      start: { idx: 23, line: 1, column: 24 },
                      end: { idx: 24, line: 1, column: 25 }
                    }
                  },
                  {
                    type: :ident,
                    value: "black",
                    position: {
                      start: { idx: 24, line: 1, column: 25 },
                      end: { idx: 29, line: 1, column: 30 }
                    }
                  },
                  {
                    type: :whitespace,
                    value: " ",
                    position: {
                      start: { idx: 29, line: 1, column: 30 },
                      end: { idx: 30, line: 1, column: 31 }
                    }
                  }
                ]
              }
            },
            {
              type: :qualified_rule,
              prelude: [
                {
                  type: :delim,
                  value: ".",
                  position: {
                    start: { idx: 42, line: 2, column: 12 },
                    end: { idx: 43, line: 2, column: 13 }
                  }
                },
                {
                  type: :ident,
                  value: "test",
                  position: {
                    start: { idx: 43, line: 2, column: 13 },
                    end: { idx: 47, line: 2, column: 17 }
                  }
                },
                {
                  type: :whitespace,
                  value: " ",
                  position: {
                    start: { idx: 47, line: 2, column: 17 },
                    end: { idx: 48, line: 2, column: 18 }
                  }
                }
              ],
              value: nil,
              block: {
                type: :simple_block,
                associated_token: {
                  type: :left_curly,
                  value: "{",
                  position: {
                    start: { idx: 48, line: 2, column: 18 },
                    end: { idx: 49, line: 2, column: 19 }
                  }
                },
                value: [
                  {
                    type: :whitespace,
                    value: " ",
                    position: {
                      start: { idx: 49, line: 2, column: 19 },
                      end: { idx: 50, line: 2, column: 20 }
                    }
                  },
                  {
                    type: :ident,
                    value: "font-size",
                    position: {
                      start: { idx: 50, line: 2, column: 20 },
                      end: { idx: 59, line: 2, column: 29 }
                    }
                  },
                  {
                    type: :colon,
                    value: ":",
                    position: {
                      start: { idx: 59, line: 2, column: 29 },
                      end: { idx: 60, line: 2, column: 30 }
                    }
                  },
                  {
                    type: :whitespace,
                    value: " ",
                    position: {
                      start: { idx: 60, line: 2, column: 30 },
                      end: { idx: 61, line: 2, column: 31 }
                    }
                  },
                  {
                    type: :dimension,
                    value: 17,
                    flag: :integer,
                    unit: "px",
                    position: {
                      start: { idx: 61, line: 2, column: 31 },
                      end: { idx: 65, line: 2, column: 35 }
                    }
                  },
                  {
                    type: :semicolon,
                    value: ";",
                    position: {
                      start: { idx: 65, line: 2, column: 35 },
                      end: { idx: 66, line: 2, column: 36 }
                    }
                  },
                  {
                    type: :whitespace,
                    value: " ",
                    position: {
                      start: { idx: 66, line: 2, column: 36 },
                      end: { idx: 67, line: 2, column: 37 }
                    }
                  }
                ]
              }
            }
          ]
        })
      end

      it "parses a real stylesheet" do
        data = fixture_data("vito.io.css")
        parser_for.call(data).parse_stylesheet
      end
    end
  end
end
