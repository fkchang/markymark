# frozen_string_literal: true

require_relative 'base'

module Markymark
  module Org
    module Nodes
      # Hyperlink node
      class Link < Base
        attr_reader :url, :description

        def initialize(url:, description: nil, children: [])
          super(children: children)
          @url = url
          @description = description
        end

        def ==(other)
          super && other.url == url && other.description == description
        end
      end
    end
  end
end
