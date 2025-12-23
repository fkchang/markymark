# frozen_string_literal: true

require_relative "markymark/version"
require_relative "markymark/pumadev_manager"
require_relative "markymark/app_installer"
require_relative "markymark/init_wizard"
require_relative "markymark/org"
require_relative "markymark/server_simple"
require_relative "markymark/cli"

module Markymark
  class Error < StandardError; end
end
