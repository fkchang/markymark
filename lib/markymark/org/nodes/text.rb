# frozen_string_literal: true

require_relative 'base'

module Markymark
  module Org
    module Nodes
      # Plain text node
      class Text < Base
        attr_reader :content

        def initialize(content:)
          super(children: [])
          @content = content
        end

        def ==(other)
          other.class == self.class && other.content == content
        end
      end

      # Bold text *bold*
      class Bold < Base
        # Children are inline nodes
      end

      # Italic text /italic/
      class Italic < Base
        # Children are inline nodes
      end

      # Inline code ~code~ or =verbatim=
      class Code < Base
        attr_reader :content

        def initialize(content:)
          super(children: [])
          @content = content
        end

        def ==(other)
          other.class == self.class && other.content == content
        end
      end

      # Strikethrough +strikethrough+
      class Strikethrough < Base
        # Children are inline nodes
      end

      # Underline _underline_
      class Underline < Base
        # Children are inline nodes
      end
    end
  end
end
