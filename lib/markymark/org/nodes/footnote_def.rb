# frozen_string_literal: true

require_relative 'base'

module Markymark
  module Org
    module Nodes
      # Footnote definition [fn:label] content...
      class FootnoteDef < Base
        attr_reader :label

        def initialize(label:, children: [])
          super(children: children)
          @label = label
        end

        def ==(other)
          super && other.label == label
        end
      end
    end
  end
end
