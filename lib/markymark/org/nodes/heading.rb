# frozen_string_literal: true

require_relative 'base'

module Markymark
  module Org
    module Nodes
      # Heading node with level, TODO state, tags, and properties drawer
      class Heading < Base
        attr_reader :level, :text, :todo_state, :tags, :custom_id, :properties_drawer

        def initialize(
          level:,
          text:,
          children: [],
          todo_state: nil,
          tags: [],
          custom_id: nil,
          properties_drawer: {}
        )
          super(children: children)
          @level = level
          @text = text
          @todo_state = todo_state
          @tags = tags.freeze
          @custom_id = custom_id
          @properties_drawer = properties_drawer.freeze
        end

        def ==(other)
          super &&
            other.level == level &&
            other.text == text &&
            other.todo_state == todo_state &&
            other.tags == tags &&
            other.custom_id == custom_id &&
            other.properties_drawer == properties_drawer
        end
      end
    end
  end
end
