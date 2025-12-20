# frozen_string_literal: true

require_relative 'lib/markymark'

# For pumadev: Load root path from PumadevManager if in pumadev mode
if Markymark::PumadevManager.active?
  # Load from pumadev configuration
  root_file = Markymark::PumadevManager.env_file_path
  root = File.exist?(root_file) ? File.read(root_file).strip : Dir.pwd
else
  # Fall back to environment variable or current directory
  root = ENV['MARKYMARK_ROOT'] || Dir.pwd
end

root = File.expand_path(root)
Markymark::ServerSimple.root_path = root
Markymark::ServerSimple.real_root_path = File.realpath(root)

run Markymark::ServerSimple
