# frozen_string_literal: true

require 'cgi'
require 'rouge'
require_relative 'nodes'
require_relative 'id_generator'

module Markymark
  module Org
    # Renders Org AST to HTML
    class Renderer
      def initialize(id_generator: IdGenerator.new, include_tag_index: true)
        @id_generator = id_generator
        @heading_stack = []
        @tag_index = {}  # tag -> [{id:, text:, level:}]
        @include_tag_index = include_tag_index
      end

      def render(document)
        @tag_index = {}
        @heading_ids = {}  # heading text (lowercased) -> actual ID
        @current_document = document  # Store for state classification

        # First pass: collect heading IDs for internal link resolution
        collect_heading_ids(document)

        # Reset ID generator so render pass generates same IDs
        @id_generator.reset!

        html = render_node(document)

        # Append tag index if we have tags and it's enabled
        if @include_tag_index && @tag_index.any?
          html += render_tag_index
        end

        html
      end

      private

      # Collect heading text -> ID mappings for internal link resolution
      def collect_heading_ids(node, ancestors: [])
        return unless node.respond_to?(:children) && node.children

        node.children.each do |child|
          if child.type == :heading && child.respond_to?(:text)
            # Generate the ID the same way render_heading does
            id = @id_generator.heading_id(child, ancestors: ancestors)
            # Store mapping from heading text (lowercased) to actual ID
            @heading_ids[child.text.downcase.strip] = id
            # Recurse into heading's children
            collect_heading_ids(child, ancestors: ancestors + [child])
          else
            collect_heading_ids(child, ancestors: ancestors)
          end
        end
      end

      def render_node(node)
        method_name = "render_#{node.type}"
        if respond_to?(method_name, true)
          send(method_name, node)
        else
          render_children(node)
        end
      end

      def render_children(node)
        return '' unless node.respond_to?(:children) && node.children
        node.children.map { |c| render_node(c) }.join
      end

      def render_document(node)
        html = render_children(node)

        # If document has title, prepend it
        if node.title && !node.title.empty?
          html = "<h1 class=\"org-document-title\">#{escape_html(node.title)}</h1>\n#{html}"
        end

        html
      end

      def render_heading(node)
        id = @id_generator.heading_id(node, ancestors: @heading_stack)
        tag_level = [node.level, 6].min
        tag = "h#{tag_level}"

        # Collect tags for tag index
        if node.tags && node.tags.any?
          node.tags.each do |t|
            @tag_index[t] ||= []
            @tag_index[t] << { id: id, text: node.text, level: node.level, todo: node.todo_state }
          end
        end

        @heading_stack.push(node)
        children_html = render_children(node)
        @heading_stack.pop

        # Build heading content with optional TODO badge and tags
        heading_content = []

        if node.todo_state && !node.todo_state.empty?
          todo_class = todo_state_class(node.todo_state)
          heading_content << %(<span class="#{todo_class}">#{escape_html(node.todo_state)}</span> )
        end

        heading_content << escape_html(node.text)

        if node.tags && node.tags.any?
          tag_spans = node.tags.map do |t|
            %(<a href="#tag-index-#{escape_html(t)}" class="org-tag">#{escape_html(t)}</a>)
          end
          heading_content << %( <span class="org-tags">#{tag_spans.join}</span>)
        end

        # Properties drawer (collapsible)
        props_html = ''
        if node.properties_drawer && node.properties_drawer.any?
          props_html = render_properties_drawer(node.properties_drawer)
        end

        <<~HTML
          <section class="org-heading" data-org-level="#{node.level}">
            <#{tag} id="#{id}">#{heading_content.join}</#{tag}>
            #{props_html}
            #{children_html}
          </section>
        HTML
      end

      def render_properties_drawer(props)
        return '' if props.nil? || props.empty?

        items = props.map do |key, value|
          "<dt>#{escape_html(key)}</dt><dd>#{escape_html(value)}</dd>"
        end.join("\n")

        <<~HTML
          <details class="org-properties">
            <summary>Properties</summary>
            <dl>
              #{items}
            </dl>
          </details>
        HTML
      end

      def render_paragraph(node)
        content = render_children(node)
        return '' if content.strip.empty?
        "<p>#{content}</p>\n"
      end

      def render_text(node)
        escape_html(node.content)
      end

      def render_bold(node)
        "<strong>#{render_children(node)}</strong>"
      end

      def render_italic(node)
        "<em>#{render_children(node)}</em>"
      end

      def render_code(node)
        "<code>#{escape_html(node.content)}</code>"
      end

      def render_strikethrough(node)
        "<del>#{render_children(node)}</del>"
      end

      def render_underline(node)
        "<u>#{render_children(node)}</u>"
      end

      def render_link(node)
        if node.internal?
          render_internal_link(node)
        elsif node.cross_doc?
          render_cross_doc_link(node)
        else
          render_external_link(node)
        end
      end

      def render_internal_link(node)
        # Internal link: [[*Heading]] or [[#custom-id]]
        anchor = if node.anchor_type == :heading && node.anchor_value
                   # Look up actual heading ID from collected mappings
                   @heading_ids[node.anchor_value.downcase.strip] ||
                     generate_anchor(node.anchor_type, node.anchor_value)
                 else
                   generate_anchor(node.anchor_type, node.anchor_value)
                 end
        href = "##{anchor}"
        description = node.description || node.anchor_value || anchor
        %(<a href="#{escape_html(href)}" class="org-internal-link">#{escape_html(description)}</a>)
      end

      def render_cross_doc_link(node)
        # Cross-document link: [[file:doc.org::*Heading]]
        url = node.url || ''
        url = url.sub(/^file:/, '') if url.start_with?('file:')

        # Use relative path - server handles routing via click interception
        # This keeps links simple and lets the existing navigation work
        href = url

        if node.anchor_type && node.anchor_value
          anchor = generate_anchor(node.anchor_type, node.anchor_value)
          if node.anchor_type == :search
            # For search, add query param (will be handled by JS)
            href = "#{href}?search=#{CGI.escape(node.anchor_value)}"
          else
            # For heading/custom_id, use fragment
            href = "#{href}##{anchor}"
          end
        end

        description = node.description || node.anchor_value || url
        %(<a href="#{escape_html(href)}" class="org-cross-doc-link">#{escape_html(description)}</a>)
      end

      def render_external_link(node)
        # External link: https://..., mailto:..., etc.
        url = node.url || ''
        escaped_url = escape_html(url)
        description = node.description ? escape_html(node.description) : escaped_url
        %(<a href="#{escaped_url}" class="org-external-link" target="_blank" rel="noopener">#{description}</a>)
      end

      def generate_anchor(anchor_type, anchor_value)
        return '' unless anchor_value

        case anchor_type
        when :custom_id
          # Pass through custom IDs as-is
          anchor_value
        when :heading
          # Slugify heading text (same logic as IdGenerator)
          anchor_value.to_s
                      .downcase
                      .gsub(/[^a-z0-9\s-]/, '')
                      .gsub(/\s+/, '-')
                      .gsub(/-+/, '-')
                      .gsub(/^-|-$/, '')
                      .slice(0, 50)
        when :search
          # Search doesn't use fragment, but return value for description
          anchor_value
        else
          anchor_value
        end
      end

      def render_src_block(node)
        id_attr = node.name ? %( id="#{@id_generator.block_id(node.name)}") : ''
        caption = node.name ? %(<figcaption>#{escape_html(node.name)}</figcaption>\n) : ''

        # Use Rouge for syntax highlighting if language is specified
        highlighted = if node.language && !node.language.empty?
                        highlight_code(node.content, node.language)
                      else
                        "<pre><code>#{escape_html(node.content)}</code></pre>"
                      end

        <<~HTML
          <figure class="org-src-block"#{id_attr}>
            #{caption}#{highlighted}
          </figure>
        HTML
      end

      def highlight_code(code, language)
        lexer = Rouge::Lexer.find_fancy(language) || Rouge::Lexers::PlainText.new
        formatter = Rouge::Formatters::HTML.new
        highlighted = formatter.format(lexer.lex(code))
        %(<div class="highlight"><pre class="highlight"><code>#{highlighted}</code></pre></div>)
      rescue => e
        # Fall back to plain code if highlighting fails
        "<pre><code class=\"language-#{escape_html(language)}\">#{escape_html(code)}</code></pre>"
      end

      def render_example_block(node)
        id_attr = node.name ? %( id="#{@id_generator.block_id(node.name)}") : ''
        <<~HTML
          <pre class="org-example-block"#{id_attr}>#{escape_html(node.content)}</pre>
        HTML
      end

      def render_quote_block(node)
        children_html = render_children(node)
        %(<blockquote class="org-quote-block">\n#{children_html}</blockquote>\n)
      end

      def render_table(node)
        # Filter out separators and render rows
        rows = node.children.reject { |r| r.is_a?(Nodes::TableSeparator) }
        return '' if rows.empty?

        # Check if first row is header
        header_row = rows.first if rows.first&.header?

        parts = [%(<table class="org-table">\n)]

        if header_row
          parts << "<thead>\n"
          parts << render_table_row(header_row, cell_tag: 'th')
          parts << "</thead>\n"
          rows = rows[1..]
        end

        if rows.any?
          parts << "<tbody>\n"
          rows.each do |row|
            parts << render_table_row(row, cell_tag: 'td')
          end
          parts << "</tbody>\n"
        end

        parts << "</table>\n"
        parts.join
      end

      def render_table_row(node, cell_tag: 'td')
        cells = node.children.map do |cell|
          # Prefer rendered children (with inline formatting) over raw content
          content = if cell.respond_to?(:children) && cell.children && cell.children.any?
                      render_children(cell)
                    elsif cell.respond_to?(:content)
                      escape_html(cell.content)
                    else
                      ''
                    end
          "<#{cell_tag}>#{content}</#{cell_tag}>"
        end.join
        "<tr>#{cells}</tr>\n"
      end

      def render_table_separator(_node)
        '' # Separators are handled in table rendering
      end

      def render_table_cell(node)
        render_children(node)
      end

      def render_list(node)
        tag = node.ordered? ? 'ol' : 'ul'
        items = render_children(node)
        "<#{tag}>\n#{items}</#{tag}>\n"
      end

      def render_list_item(node)
        content = render_children(node)

        checkbox = ''
        if node.has_checkbox?
          checked = node.checked? ? ' checked' : ''
          disabled = ' disabled'
          checkbox = %(<input type="checkbox"#{checked}#{disabled}> )
        end

        "<li>#{checkbox}#{content}</li>\n"
      end

      def render_footnote_ref(node)
        ref_id = @id_generator.footnote_backref_id(node.label)
        def_id = @id_generator.footnote_id(node.label)
        %(<sup id="#{ref_id}"><a href="##{def_id}">[#{escape_html(node.label)}]</a></sup>)
      end

      def render_footnote_def(node)
        id = @id_generator.footnote_id(node.label)
        backref_id = @id_generator.footnote_backref_id(node.label)
        content = render_children(node)

        <<~HTML
          <div class="org-footnote-def" id="#{id}">
            <span class="org-footnote-label">[#{escape_html(node.label)}]</span>
            #{content}
            <a href="##{backref_id}" class="org-footnote-backref" title="Back to reference">&#8617;</a>
          </div>
        HTML
      end

      def render_horizontal_rule(_node)
        "<hr>\n"
      end

      def render_raw(node)
        # Render unsupported content with a comment noting the original type
        type_note = node.original_type ? " (#{node.original_type})" : ''
        <<~HTML
          <!-- Unsupported org-mode construct#{type_note} -->
          <pre class="org-raw">#{escape_html(node.content)}</pre>
        HTML
      end

      def render_tag_index
        return '' if @tag_index.empty?

        sorted_tags = @tag_index.keys.sort

        tag_sections = sorted_tags.map do |tag|
          headings = @tag_index[tag]
          heading_links = headings.map do |h|
            indent = '  ' * (h[:level] - 1)
            todo_badge = if h[:todo]
                           todo_class = "org-todo org-todo-#{h[:todo].downcase}"
                           %(<span class="#{todo_class}" style="font-size: 0.7em;">#{escape_html(h[:todo])}</span> )
                         else
                           ''
                         end
            %(#{indent}<a href="##{h[:id]}">#{todo_badge}#{escape_html(h[:text])}</a>)
          end.join("<br>\n")

          <<~HTML
            <div class="org-tag-section" id="tag-index-#{escape_html(tag)}">
              <h4><span class="org-tag">#{escape_html(tag)}</span></h4>
              <div class="org-tag-headings">
                #{heading_links}
              </div>
            </div>
          HTML
        end.join("\n")

        <<~HTML

          <section class="org-tag-index">
            <h3>Tag Index</h3>
            <div class="org-tag-grid">
              #{tag_sections}
            </div>
          </section>
        HTML
      end

      # Determine CSS class for a TODO state based on document's workflow configuration
      # Returns classes like "org-todo org-todo-active org-todo-waiting"
      def todo_state_class(state)
        return 'org-todo' if state.nil? || state.empty?

        state_lower = state.downcase
        state_upper = state.upcase

        # Determine if this is an active or done state
        state_type = if @current_document&.done_state?(state_upper)
                       'done'
                     elsif @current_document&.active_state?(state_upper)
                       'active'
                     else
                       # Unknown state - guess based on common patterns
                       %w[DONE CANCELLED CANCELED CLOSED ARCHIVED].include?(state_upper) ? 'done' : 'active'
                     end

        # Assign a color index for active states (for variety)
        color_index = if state_type == 'active' && @current_document
                        idx = @current_document.todo_states.index(state_upper) || 0
                        idx % 5  # Cycle through 5 colors
                      else
                        0
                      end

        "org-todo org-todo-#{state_type} org-todo-#{state_type}-#{color_index} org-todo-#{state_lower}"
      end

      def escape_html(text)
        CGI.escapeHTML(text.to_s)
      end
    end
  end
end
