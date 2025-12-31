# frozen_string_literal: true

require_relative 'base'

module Markymark
  module Org
    module Nodes
      # Root document node containing all content
      class Document < Base
        attr_reader :title, :properties, :todo_states, :done_states

        # Default org-mode states
        DEFAULT_TODO_STATES = %w[TODO].freeze
        DEFAULT_DONE_STATES = %w[DONE].freeze

        def initialize(children: [], title: nil, properties: {}, todo_states: nil, done_states: nil)
          super(children: children)
          @title = title
          @properties = properties.freeze
          @todo_states = (todo_states || DEFAULT_TODO_STATES).freeze
          @done_states = (done_states || DEFAULT_DONE_STATES).freeze
        end

        # Check if a state is an active (not done) state
        def active_state?(state)
          return false if state.nil?

          todo_states.include?(state.upcase)
        end

        # Check if a state is a done state
        def done_state?(state)
          return false if state.nil?

          done_states.include?(state.upcase)
        end

        # Get all known states
        def all_states
          todo_states + done_states
        end

        def ==(other)
          super &&
            other.title == title &&
            other.properties == properties &&
            other.todo_states == todo_states &&
            other.done_states == done_states
        end
      end
    end
  end
end
