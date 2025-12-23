# frozen_string_literal: true

require_relative 'base'

module Markymark
  module Org
    module Nodes
      # Root document node containing all content
      class Document < Base
        attr_reader :title, :properties

        def initialize(children: [], title: nil, properties: {})
          super(children: children)
          @title = title
          @properties = properties.freeze
        end

        def ==(other)
          super && other.title == title && other.properties == properties
        end
      end
    end
  end
end
