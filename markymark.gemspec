# frozen_string_literal: true

require_relative "lib/markymark/version"

Gem::Specification.new do |spec|
  spec.name = "markymark"
  spec.version = Markymark::VERSION
  spec.authors = ["Forrest Chang"]
  spec.email = ["fchang@hedgeye.com"]

  spec.summary = "GitHub-Flavored Markdown and Org-mode viewer with live reload and Mermaid support"
  spec.description = "A local web server for browsing Markdown and Org-mode documentation with real-time file watching, syntax highlighting, and diagram rendering"
  spec.homepage = "https://github.com/fkchang/markymark"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/fkchang/markymark"
  spec.metadata["changelog_uri"] = "https://github.com/fkchang/markymark/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "sinatra", "~> 3.0"
  spec.add_dependency "sinatra-contrib", "~> 3.0"
  spec.add_dependency "puma", "~> 6.0"
  spec.add_dependency "kramdown", "~> 2.4"
  spec.add_dependency "kramdown-parser-gfm", "~> 1.1"
  spec.add_dependency "rouge", "~> 4.0"
  spec.add_dependency "listen", "~> 3.8"
  spec.add_dependency "launchy", "~> 2.5"
  spec.add_dependency "org-ruby", "~> 0.9"

  # Ruby 3.5+ compatibility - these are being removed from stdlib
  spec.add_dependency "ostruct"
  spec.add_dependency "logger"

  # Development dependencies
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rack-test", "~> 2.0"
end
