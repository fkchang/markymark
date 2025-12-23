# frozen_string_literal: true

require_relative 'base'

module Markymark
  module Org
    module Nodes
      # Source code block
      class SrcBlock < Base
        attr_reader :language, :name, :content, :options

        def initialize(content:, language: nil, name: nil, options: {})
          super(children: [])
          @content = content
          @language = language
          @name = name
          @options = options.freeze
        end

        def ==(other)
          other.class == self.class &&
            other.content == content &&
            other.language == language &&
            other.name == name &&
            other.options == options
        end
      end
    end
  end
end
