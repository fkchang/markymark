# frozen_string_literal: true

require_relative 'base'

module Markymark
  module Org
    module Nodes
      # Hyperlink node with support for org-mode link syntax
      # Supports: [[url]], [[url][desc]], [[*heading]], [[#id]], [[file:doc.org::*heading]]
      class Link < Base
        attr_reader :url, :description, :anchor_type, :anchor_value

        # anchor_type can be:
        #   :heading   - [[*Heading Text]] or [[file:doc.org::*Heading]]
        #   :custom_id - [[#custom-id]] or [[file:doc.org::#custom-id]]
        #   :search    - [[file:doc.org::search term]]
        #   nil        - no anchor
        def initialize(url:, description: nil, anchor_type: nil, anchor_value: nil, children: [])
          super(children: children)
          @url = url
          @description = description
          @anchor_type = anchor_type
          @anchor_value = anchor_value
        end

        # Internal link to same document
        def internal?
          url.nil? || url.empty?
        end

        # Link to another .org or .md file
        def cross_doc?
          return false if url.nil?

          url.match?(/\.(org|md)($|::)/) || url.start_with?('file:')
        end

        # External URL (http, https, mailto, etc.)
        def external?
          return false if url.nil?

          url.match?(%r{^(https?|mailto|ftp)://})
        end

        def ==(other)
          super &&
            other.url == url &&
            other.description == description &&
            other.anchor_type == anchor_type &&
            other.anchor_value == anchor_value
        end
      end
    end
  end
end
