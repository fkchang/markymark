# frozen_string_literal: true

require_relative 'base'

module Markymark
  module Org
    module Nodes
      # Inline footnote reference [fn:label]
      class FootnoteRef < Base
        attr_reader :label

        def initialize(label:)
          super(children: [])
          @label = label
        end

        def ==(other)
          other.class == self.class && other.label == label
        end
      end
    end
  end
end
