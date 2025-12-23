# frozen_string_literal: true

require 'cgi'
require_relative 'nodes'
require_relative 'id_generator'

module Markymark
  module Org
    # Renders Org AST to HTML
    class Renderer
      def initialize(id_generator: IdGenerator.new)
        @id_generator = id_generator
        @heading_stack = []
      end

      def render(document)
        render_node(document)
      end

      private

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

        @heading_stack.push(node)
        children_html = render_children(node)
        @heading_stack.pop

        # Build heading content with optional TODO badge and tags
        heading_content = []

        if node.todo_state && !node.todo_state.empty?
          todo_class = "org-todo org-todo-#{node.todo_state.downcase}"
          heading_content << %(<span class="#{todo_class}">#{escape_html(node.todo_state)}</span> )
        end

        heading_content << escape_html(node.text)

        if node.tags && node.tags.any?
          tag_spans = node.tags.map { |t| %(<span class="org-tag">#{escape_html(t)}</span>) }
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
        url = escape_html(node.url)
        description = node.description ? escape_html(node.description) : url
        %(<a href="#{url}">#{description}</a>)
      end

      def render_src_block(node)
        id_attr = node.name ? %( id="#{@id_generator.block_id(node.name)}") : ''
        caption = node.name ? %(<figcaption>#{escape_html(node.name)}</figcaption>\n) : ''
        lang_class = node.language ? %( class="language-#{escape_html(node.language)}") : ''

        <<~HTML
          <figure class="org-src-block"#{id_attr}>
            #{caption}<pre><code#{lang_class}>#{escape_html(node.content)}</code></pre>
          </figure>
        HTML
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
          content = cell.respond_to?(:content) ? escape_html(cell.content) : render_children(cell)
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

      def escape_html(text)
        CGI.escapeHTML(text.to_s)
      end
    end
  end
end
