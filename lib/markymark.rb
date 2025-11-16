# frozen_string_literal: true

require_relative "markymark/version"
require_relative "markymark/file_tree"
require_relative "markymark/watcher"
require_relative "markymark/server"
require_relative "markymark/cli"

module Markymark
  class Error < StandardError; end
end
