# frozen_string_literal: true

require 'org-ruby'
require_relative 'nodes'

module Markymark
  module Org
    # Parser that wraps org-ruby and builds our AST
    class Parser
      def initialize(content)
        @content = content
        @org_parser = Orgmode::Parser.new(content)
        @footnote_definitions = {}
      end

      def parse
        children = []

        # Parse header lines (content before first headline)
        header_content = parse_body_lines(@org_parser.header_lines)
        children.concat(header_content)

        # Parse headlines recursively
        children.concat(parse_headlines(@org_parser.headlines))

        # Append collected footnote definitions at end if any
        unless @footnote_definitions.empty?
          children.concat(@footnote_definitions.values)
        end

        Nodes::Document.new(
          children: children,
          title: @org_parser.in_buffer_settings['TITLE'],
          properties: @org_parser.in_buffer_settings
        )
      end

      private

      def parse_headlines(headlines)
        return [] if headlines.nil? || headlines.empty?

        # org-ruby gives us a flat list, we need to build hierarchy
        result = []
        i = 0

        while i < headlines.length
          headline = headlines[i]

          # Find all children (headlines with level > current)
          child_headlines = []
          j = i + 1
          while j < headlines.length && headlines[j].level > headline.level
            child_headlines << headlines[j]
            j += 1
          end

          # Parse body lines for this headline
          body_content = parse_body_lines(headline.body_lines)

          # Recursively parse child headlines
          nested_content = parse_headlines(child_headlines)

          # Extract properties from property drawer
          props = extract_properties(headline)
          custom_id = props.delete('CUSTOM_ID')

          result << Nodes::Heading.new(
            level: headline.level,
            text: headline.headline_text.to_s.strip,
            todo_state: headline.keyword,
            tags: parse_tags(headline),
            custom_id: custom_id,
            properties_drawer: props,
            children: body_content + nested_content
          )

          # Skip to next sibling
          i = j
        end

        result
      end

      def parse_tags(headline)
        return [] unless headline.respond_to?(:tags) && headline.tags
        headline.tags.is_a?(Array) ? headline.tags : []
      end

      def extract_properties(headline)
        return {} unless headline.respond_to?(:property_drawer)
        props = headline.property_drawer
        return {} unless props.is_a?(Hash)
        props.transform_keys(&:to_s)
      end

      def parse_body_lines(lines)
        return [] if lines.nil? || lines.empty?

        result = []
        i = 0

        while i < lines.length
          line = lines[i]
          line_text = line.respond_to?(:to_s) ? line.to_s : line.output_text.to_s rescue ''

          # Handle different line types based on org-ruby's paragraph_type
          para_type = line.respond_to?(:paragraph_type) ? line.paragraph_type : :paragraph

          case para_type
          when :src
            # Check if this is a BEGIN_SRC line
            if line_text =~ /^\s*#\+BEGIN_SRC/i
              block, consumed = parse_src_block(lines, i)
              result << block if block
              i += consumed
              next
            else
              # Skip END_SRC lines
              i += 1
              next
            end

          when :example
            # Check if this is a BEGIN_EXAMPLE line
            if line_text =~ /^\s*#\+BEGIN_EXAMPLE/i
              block, consumed = parse_example_block(lines, i)
              result << block if block
              i += consumed
              next
            else
              # Skip END_EXAMPLE lines
              i += 1
              next
            end

          when :quote
            # Check if this is a BEGIN_QUOTE line
            if line_text =~ /^\s*#\+BEGIN_QUOTE/i
              block, consumed = parse_quote_block(lines, i)
              result << block if block
              i += consumed
              next
            else
              # Skip END_QUOTE lines
              i += 1
              next
            end

          when :raw_text
            # Skip #+KEYWORD lines like #+NAME:, etc. (handled separately when parsing blocks)
            i += 1
            next

          when :table_row, :table_header, :table_separator
            table, consumed = parse_table(lines, i)
            result << table if table
            i += consumed
            next

          when :unordered_list, :ordered_list, :list_item
            list, consumed = parse_list(lines, i)
            result << list if list
            i += consumed
            next

          when :horizontal_rule, :rule
            result << Nodes::HorizontalRule.new
            i += 1
            next

          when :comment, :blank, :property_drawer_begin, :property_drawer_end, :property_drawer, :heading1, :heading2, :heading3, :heading4, :heading5, :heading6
            # Skip comments, blank lines, property drawers, and heading refs in body (handled separately)
            i += 1
            next

          else
            # Check for footnote definition
            if line_text =~ /^\[fn:([^\]]+)\]\s*(.*)/
              label = $1
              content = $2
              @footnote_definitions[label] = Nodes::FootnoteDef.new(
                label: label,
                children: [Nodes::Paragraph.new(children: parse_inline(content))]
              )
              i += 1
              next
            end

            # Regular paragraph text
            if line_text.strip.length > 0
              result << Nodes::Paragraph.new(children: parse_inline(line_text))
            end
            i += 1
          end
        end

        result
      end

      def parse_src_block(lines, start_index)
        return [nil, 1] if start_index >= lines.length

        first_line = lines[start_index]
        first_text = first_line.to_s

        # Extract language from #+BEGIN_SRC line
        language = nil
        name = nil
        options = {}

        if first_text =~ /^\s*#\+BEGIN_SRC\s*(\S+)?/i
          language = $1
        end

        # Check for #+NAME: on previous lines
        if start_index > 0
          prev_text = lines[start_index - 1].to_s
          if prev_text =~ /^\s*#\+NAME:\s*(.+)/i
            name = $1.strip
          end
        end

        # Collect content until END_SRC
        content_lines = []
        i = start_index + 1

        while i < lines.length
          line = lines[i]
          line_text = line.to_s
          para_type = line.respond_to?(:paragraph_type) ? line.paragraph_type : nil

          # Check for end of block (para_type :src with END_SRC content)
          if para_type == :src || line_text =~ /^\s*#\+END_SRC/i
            i += 1
            break
          end

          content_lines << line_text
          i += 1
        end

        block = Nodes::SrcBlock.new(
          content: content_lines.join("\n"),
          language: language,
          name: name,
          options: options
        )

        [block, i - start_index]
      end

      def parse_example_block(lines, start_index)
        return [nil, 1] if start_index >= lines.length

        content_lines = []
        i = start_index + 1

        while i < lines.length
          line = lines[i]
          line_text = line.to_s
          para_type = line.respond_to?(:paragraph_type) ? line.paragraph_type : nil

          # Check for end of block (para_type :example with END_EXAMPLE content)
          if para_type == :example || line_text =~ /^\s*#\+END_EXAMPLE/i
            i += 1
            break
          end

          content_lines << line_text
          i += 1
        end

        block = Nodes::ExampleBlock.new(content: content_lines.join("\n"))
        [block, i - start_index]
      end

      def parse_quote_block(lines, start_index)
        return [nil, 1] if start_index >= lines.length

        content_lines = []
        i = start_index + 1

        while i < lines.length
          line = lines[i]
          line_text = line.to_s
          para_type = line.respond_to?(:paragraph_type) ? line.paragraph_type : nil

          # Check for end of block (para_type :quote with END_QUOTE content)
          if para_type == :quote || line_text =~ /^\s*#\+END_QUOTE/i
            i += 1
            break
          end

          content_lines << line_text
          i += 1
        end

        # Parse content as paragraphs
        children = content_lines.reject(&:empty?).map do |line|
          Nodes::Paragraph.new(children: parse_inline(line))
        end

        block = Nodes::QuoteBlock.new(children: children)
        [block, i - start_index]
      end

      def parse_table(lines, start_index)
        return [nil, 1] if start_index >= lines.length

        rows = []
        i = start_index
        first_data_row = true

        while i < lines.length
          line = lines[i]
          para_type = line.respond_to?(:paragraph_type) ? line.paragraph_type : nil
          line_text = line.to_s.strip

          unless [:table_row, :table_header, :table_separator].include?(para_type) ||
                 line_text.start_with?('|')
            break
          end

          if para_type == :table_separator || line_text =~ /^\|[-+]+\|$/
            rows << Nodes::TableSeparator.new
          else
            # Parse cells from table row
            cells = parse_table_row(line_text)
            is_header = first_data_row && rows.empty?
            rows << Nodes::TableRow.new(children: cells, header: is_header)
            first_data_row = false
          end

          i += 1
        end

        # Mark first row as header if followed by separator
        if rows.length >= 2 && rows[1].is_a?(Nodes::TableSeparator)
          rows[0] = Nodes::TableRow.new(children: rows[0].children, header: true)
        end

        table = Nodes::Table.new(children: rows)
        [table, i - start_index]
      end

      def parse_table_row(line_text)
        # Split by | and extract cells
        parts = line_text.split('|')
        # First and last are typically empty due to leading/trailing |
        cells = parts[1..-2] || parts
        cells.map do |cell_content|
          Nodes::TableCell.new(
            content: cell_content.strip,
            children: parse_inline(cell_content.strip)
          )
        end
      end

      def parse_list(lines, start_index)
        return [nil, 1] if start_index >= lines.length

        first_line = lines[start_index]
        first_text = first_line.to_s

        # Determine if ordered or unordered
        ordered = !!(first_text =~ /^\s*\d+[.)]/) # Convert match index/nil to boolean

        items = []
        i = start_index
        base_indent = first_text[/^\s*/].length

        while i < lines.length
          line = lines[i]
          line_text = line.to_s
          para_type = line.respond_to?(:paragraph_type) ? line.paragraph_type : nil

          # Check if still in list
          current_indent = line_text[/^\s*/].length
          is_list_item = [:unordered_list, :ordered_list, :list_item].include?(para_type) ||
                         line_text =~ /^\s*[-+*]\s/ ||
                         line_text =~ /^\s*\d+[.)]\s/

          break unless is_list_item || (line_text.strip.empty? && i + 1 < lines.length)
          break if current_indent < base_indent && !line_text.strip.empty?

          if is_list_item
            item, consumed = parse_list_item(lines, i)
            items << item if item
            i += consumed
          else
            i += 1
          end
        end

        list = Nodes::List.new(children: items, ordered: ordered)
        [list, i - start_index]
      end

      def parse_list_item(lines, start_index)
        return [nil, 1] if start_index >= lines.length

        line_text = lines[start_index].to_s

        # Extract checkbox state if present
        checkbox_state = nil
        content = line_text

        if line_text =~ /^\s*[-+*]\s+\[(.)\]\s+(.*)/
          checkbox_char = $1
          content = $2
          checkbox_state = case checkbox_char
                           when 'X', 'x' then :checked
                           when ' ' then :unchecked
                           when '-' then :partial
                           end
        elsif line_text =~ /^\s*[-+*]\s+(.*)/
          content = $1
        elsif line_text =~ /^\s*\d+[.)]\s+(.*)/
          content = $1
        end

        children = parse_inline(content)

        item = Nodes::ListItem.new(
          children: [Nodes::Paragraph.new(children: children)],
          checkbox_state: checkbox_state
        )

        [item, 1]
      end

      def parse_inline(text)
        return [] if text.nil? || text.empty?

        nodes = []
        remaining = text.to_s

        while remaining.length > 0
          # Try to match inline elements in order of precedence

          # Links: [[url][description]] or [[url]]
          if remaining =~ /\A\[\[([^\]]+)\](?:\[([^\]]+)\])?\]/
            url = $1
            description = $2
            nodes << Nodes::Link.new(url: url, description: description)
            remaining = $'
            next
          end

          # Footnote reference: [fn:label]
          if remaining =~ /\A\[fn:([^\]]+)\]/
            label = $1
            nodes << Nodes::FootnoteRef.new(label: label)
            remaining = $'
            next
          end

          # Bold: *bold*
          if remaining =~ /\A\*([^\*]+)\*/
            content = $1
            nodes << Nodes::Bold.new(children: [Nodes::Text.new(content: content)])
            remaining = $'
            next
          end

          # Italic: /italic/
          if remaining =~ %r{\A/([^/]+)/}
            content = $1
            nodes << Nodes::Italic.new(children: [Nodes::Text.new(content: content)])
            remaining = $'
            next
          end

          # Code: ~code~ or =verbatim=
          if remaining =~ /\A~([^~]+)~/
            content = $1
            nodes << Nodes::Code.new(content: content)
            remaining = $'
            next
          end

          if remaining =~ /\A=([^=]+)=/
            content = $1
            nodes << Nodes::Code.new(content: content)
            remaining = $'
            next
          end

          # Strikethrough: +strikethrough+
          if remaining =~ /\A\+([^\+]+)\+/
            content = $1
            nodes << Nodes::Strikethrough.new(children: [Nodes::Text.new(content: content)])
            remaining = $'
            next
          end

          # Underline: _underline_
          if remaining =~ /\A_([^_]+)_/
            content = $1
            nodes << Nodes::Underline.new(children: [Nodes::Text.new(content: content)])
            remaining = $'
            next
          end

          # Plain text - consume until next potential markup
          match = remaining.match(/\A([^\[\*\/_~=\+]+)/)
          if match && match[1].length > 0
            nodes << Nodes::Text.new(content: match[1])
            remaining = remaining[match[1].length..]
          else
            # Consume single character if no pattern matched
            nodes << Nodes::Text.new(content: remaining[0])
            remaining = remaining[1..]
          end
        end

        nodes
      end
    end
  end
end
