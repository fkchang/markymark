# frozen_string_literal: true

require_relative 'base'

module Markymark
  module Org
    module Nodes
      # Raw/unsupported content - rendered as-is with a note
      # TODO: Future versions should handle more constructs:
      # - Drawers beyond PROPERTIES
      # - Macros
      # - Custom blocks
      # - Inline images
      # - Timestamps/dates
      class Raw < Base
        attr_reader :content, :original_type

        def initialize(content:, original_type: nil)
          super(children: [])
          @content = content
          @original_type = original_type
        end

        def ==(other)
          other.class == self.class &&
            other.content == content &&
            other.original_type == original_type
        end
      end
    end
  end
end
