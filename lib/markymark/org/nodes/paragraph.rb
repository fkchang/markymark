# frozen_string_literal: true

require_relative 'base'

module Markymark
  module Org
    module Nodes
      # Paragraph containing inline content
      class Paragraph < Base
        # Children are inline nodes (Text, Bold, Italic, Link, etc.)
      end
    end
  end
end
