# frozen_string_literal: true

require_relative 'lib/markymark'

# For pumadev: Use environment variable or current directory
root = ENV['MARKYMARK_ROOT'] || Dir.pwd
Markymark::ServerSimple.root_path = root
Markymark::ServerSimple.real_root_path = File.realpath(root)

run Markymark::ServerSimple
