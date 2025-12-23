# frozen_string_literal: true

module Markymark
  module Org
    module Nodes
      # Base class for all Org-mode AST nodes
      class Base
        attr_reader :children

        def initialize(children: [])
          @children = children.freeze
        end

        def type
          self.class.name.split('::').last.gsub(/([a-z])([A-Z])/, '\1_\2').downcase.to_sym
        end

        # Visitor pattern support
        def accept(visitor)
          visitor.send("visit_#{type}", self)
        end

        # Allow nodes to be compared for testing
        def ==(other)
          other.class == self.class && other.children == children
        end
      end
    end
  end
end
