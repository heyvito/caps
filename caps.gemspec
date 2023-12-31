# frozen_string_literal: true

require_relative "lib/caps/version"

Gem::Specification.new do |spec|
  spec.name = "caps"
  spec.version = Caps::VERSION
  spec.authors = ["Victor Gama"]
  spec.email = ["hey@vito.io"]

  spec.summary = "Caps parses CSS into Abstract Syntax Trees"
  spec.description = spec.summary
  spec.homepage = "https://github.com/heyvito/caps"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"
end
