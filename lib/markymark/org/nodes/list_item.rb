# frozen_string_literal: true

require_relative 'base'

module Markymark
  module Org
    module Nodes
      # List item, optionally with checkbox
      class ListItem < Base
        attr_reader :checkbox_state

        # checkbox_state: nil (no checkbox), :unchecked, :checked, :partial
        def initialize(children: [], checkbox_state: nil)
          super(children: children)
          @checkbox_state = checkbox_state
        end

        def has_checkbox?
          !@checkbox_state.nil?
        end

        def checked?
          @checkbox_state == :checked
        end

        def ==(other)
          super && other.checkbox_state == checkbox_state
        end
      end
    end
  end
end
