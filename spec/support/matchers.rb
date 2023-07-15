# frozen_string_literal: true

module CapsMatchers
  class DeclarationMatcher
    def initialize(name, value, **opts)
      @name = name
      @value = value
      @opts = opts
      @error = nil
    end

    def error!(msg)
      base = "Expected #{@obj.inspect}"
      @error_forward = "#{base} to #{msg}"
      @error_reverse = "#{base} not to #{msg}"
      false
    end

    def matches?(obj)
      unless obj.is_a? Hash
        @error_forward = "Expected object to be a Hash, found #{obj.class.name} instead"
        @error_reverse = "Expected object not to be a Hash"
        return false
      end

      obj.reject! { |k| k == :position }
      @obj = obj

      return error! "be a declaration" unless obj[:type] == :declaration

      return error! "have '#{@name}' as name" unless obj.dig(:name, :value) == @name

      return error! "have '#{@name}' as value" unless obj[:value].map do |v|
        v.reject { |k| k == :position }
      end == @value

      @opts.each do |k, v|
        return error! "have an extra property #{k.inspect} set to #{v}" if obj[k] != v
      end

      true
    end

    def failure_message
      @error_forward
    end

    def failure_message_when_negated
      @error_reverse
    end
  end

  def be_a_declaration(name, value, **opts)
    DeclarationMatcher.new(name, value, **opts)
  end
end
