require_relative 'lib/jeeves/version'

Gem::Specification.new do |spec|
  spec.name          = "jeeves-git-commit"
  spec.version       = Jeeves::VERSION
  spec.authors       = ["Justin Bishop"]
  spec.email         = ["jubishop@gmail.com"]
  spec.summary       = "AI-powered Git commit message generator"
  spec.description   = "Jeeves is a command-line tool that helps you create AI-powered Git commit messages"
  spec.homepage      = "https://github.com/jubishop/Jeeves"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 3.3", "< 4.1")
  
  spec.files         = Dir.glob("lib/{*,jeeves/*}.rb") + %w[bin/jeeves README.md LICENSE config/prompt]
  spec.bindir        = "bin"
  spec.executables   = ["jeeves"]
  
  spec.add_dependency "json", "~> 2.0"
  
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "webmock", "~> 3.0"
end
