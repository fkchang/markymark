# frozen_string_literal: true

require_relative 'org/nodes'
require_relative 'org/id_generator'
require_relative 'org/parser'
require_relative 'org/renderer'

module Markymark
  module Org
    # Convenience method to parse and render org content to HTML
    def self.to_html(content)
      document = Parser.new(content).parse
      Renderer.new.render(document)
    end
  end
end
