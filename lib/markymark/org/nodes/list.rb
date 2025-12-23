# frozen_string_literal: true

require_relative 'base'

module Markymark
  module Org
    module Nodes
      # Ordered or unordered list
      class List < Base
        attr_reader :ordered

        def initialize(children: [], ordered: false)
          super(children: children)
          @ordered = ordered
        end

        def ordered?
          @ordered
        end

        def ==(other)
          super && other.ordered == ordered
        end
      end
    end
  end
end
