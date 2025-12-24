# frozen_string_literal: true

require 'set'

module Markymark
  module Org
    # Generates stable, URL-safe IDs for org-mode elements
    class IdGenerator
      def initialize
        @seen_ids = Set.new
      end

      # Generate ID for a heading
      # Priority: CUSTOM_ID property > heading path slug
      def heading_id(heading, ancestors: [])
        if heading.custom_id && !heading.custom_id.empty?
          return ensure_unique(slugify(heading.custom_id))
        end

        # Build path from ancestors + current heading
        path_parts = ancestors.map { |h| h.respond_to?(:text) ? h.text : h.to_s }
        path_parts << (heading.respond_to?(:text) ? heading.text : heading.to_s)
        base_slug = path_parts.map { |t| slugify(t) }.reject(&:empty?).join('--')
        base_slug = 'heading' if base_slug.empty?
        ensure_unique(base_slug)
      end

      # Generate ID for named blocks
      def block_id(name)
        return nil if name.nil? || name.empty?
        ensure_unique("block-#{slugify(name)}")
      end

      # Generate ID for footnote definitions
      # Note: Footnote IDs are NOT made unique - multiple refs to same footnote
      # should link to the same definition
      def footnote_id(label)
        "fn-#{slugify(label)}"
      end

      # Generate ID for footnote references (backref targets)
      # Note: Not made unique - same label = same ID (for backlinks)
      def footnote_backref_id(label)
        "fnref-#{slugify(label)}"
      end

      # Reset seen IDs (useful for testing or rendering multiple documents)
      def reset!
        @seen_ids.clear
      end

      private

      def slugify(text)
        text.to_s
            .downcase
            .gsub(/[^a-z0-9\s-]/, '')  # Remove non-alphanumeric except spaces and hyphens
            .gsub(/\s+/, '-')           # Spaces to hyphens
            .gsub(/-+/, '-')            # Collapse multiple hyphens
            .gsub(/^-|-$/, '')          # Trim leading/trailing hyphens
            .slice(0, 50)               # Limit length
      end

      def ensure_unique(base_id)
        base_id = 'id' if base_id.nil? || base_id.empty?
        id = base_id
        counter = 1
        while @seen_ids.include?(id)
          id = "#{base_id}-#{counter}"
          counter += 1
        end
        @seen_ids << id
        id
      end
    end
  end
end
