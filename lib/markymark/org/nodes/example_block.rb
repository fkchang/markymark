# frozen_string_literal: true

require_relative 'base'

module Markymark
  module Org
    module Nodes
      # Example/verbatim block
      class ExampleBlock < Base
        attr_reader :content, :name

        def initialize(content:, name: nil)
          super(children: [])
          @content = content
          @name = name
        end

        def ==(other)
          other.class == self.class &&
            other.content == content &&
            other.name == name
        end
      end
    end
  end
end
