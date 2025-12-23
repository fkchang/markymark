# frozen_string_literal: true

require_relative 'base'

module Markymark
  module Org
    module Nodes
      # Horizontal rule (------)
      class HorizontalRule < Base
        def initialize
          super(children: [])
        end
      end
    end
  end
end
