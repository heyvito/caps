# frozen_string_literal: true

require_relative "parser/infra"
require_relative "parser/helpers"
require_relative "parser/entrypoints"
require_relative "parser/consumers"

module Caps
  class Parser
    using Caps::Parser::Helpers
    include Caps::Parser::Consumers
    include Caps::Parser::Entrypoints
  end
end
