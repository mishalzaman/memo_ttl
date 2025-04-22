# frozen_string_literal: true

require_relative "lib/memo_ttl/version"

Gem::Specification.new do |spec|
  spec.name          = "memo_ttl"
  spec.version       = MemoTtl::VERSION
  spec.authors       = ["Mishal Zaman"]
  spec.email         = ["mishalzaman@gmail.com"]

  spec.summary       = "Memoization with LRU and TTL"
  spec.description   = "Adds memoization to methods with optional time-to-live and LRU eviction"
  spec.homepage      = "https://github.com/mishalzaman/memo_ttl"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["allowed_push_host"]   = "https://rubygems.org"
  spec.metadata["homepage_uri"]        = spec.homepage
  spec.metadata["source_code_uri"]     = "https://github.com/mishalzaman/memo_ttl"
  spec.metadata["changelog_uri"]       = "https://github.com/mishalzaman/memo_ttl/blob/main/CHANGELOG.md"

  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      f == File.basename(__FILE__) || f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
