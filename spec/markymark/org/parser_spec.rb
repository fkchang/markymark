# frozen_string_literal: true

require 'spec_helper'
require 'markymark'

RSpec.describe Markymark::Org::Parser do
  describe '#parse' do
    it 'returns a Document node' do
      parser = described_class.new('* Heading')
      doc = parser.parse

      expect(doc).to be_a(Markymark::Org::Nodes::Document)
    end

    it 'extracts document title from #+TITLE' do
      content = "#+TITLE: My Document\n* Heading"
      parser = described_class.new(content)
      doc = parser.parse

      expect(doc.title).to eq('My Document')
    end

    describe 'headings' do
      it 'parses heading levels' do
        content = "* Level 1\n** Level 2\n*** Level 3"
        parser = described_class.new(content)
        doc = parser.parse

        expect(doc.children.first).to be_a(Markymark::Org::Nodes::Heading)
        expect(doc.children.first.level).to eq(1)
      end

      it 'extracts TODO state from headings' do
        content = "* TODO Task one\n* DONE Task two"
        parser = described_class.new(content)
        doc = parser.parse

        expect(doc.children[0].todo_state).to eq('TODO')
        expect(doc.children[1].todo_state).to eq('DONE')
      end

      it 'parses tags from headings' do
        content = "* Heading :tag1:tag2:"
        parser = described_class.new(content)
        doc = parser.parse

        expect(doc.children.first.tags).to include('tag1', 'tag2')
      end

      it 'extracts CUSTOM_ID from properties drawer' do
        content = <<~ORG
          * Heading
          :PROPERTIES:
          :CUSTOM_ID: my-custom-id
          :END:
        ORG
        parser = described_class.new(content)
        doc = parser.parse

        expect(doc.children.first.custom_id).to eq('my-custom-id')
      end

      it 'extracts other properties from drawer' do
        content = <<~ORG
          * Heading
          :PROPERTIES:
          :CATEGORY: testing
          :PRIORITY: A
          :END:
        ORG
        parser = described_class.new(content)
        doc = parser.parse

        props = doc.children.first.properties_drawer
        expect(props['CATEGORY']).to eq('testing')
        expect(props['PRIORITY']).to eq('A')
      end

      it 'nests child headings correctly' do
        content = "* Parent\n** Child\n*** Grandchild\n* Sibling"
        parser = described_class.new(content)
        doc = parser.parse

        expect(doc.children.length).to eq(2)
        parent = doc.children[0]
        expect(parent.text).to eq('Parent')

        # Find nested heading
        child_headings = parent.children.select { |c| c.is_a?(Markymark::Org::Nodes::Heading) }
        expect(child_headings.length).to eq(1)
        expect(child_headings[0].text).to eq('Child')
      end
    end

    describe 'paragraphs and inline formatting' do
      it 'parses paragraph text' do
        content = "* Heading\n\nSome paragraph text."
        parser = described_class.new(content)
        doc = parser.parse

        heading = doc.children.first
        paragraphs = heading.children.select { |c| c.is_a?(Markymark::Org::Nodes::Paragraph) }
        expect(paragraphs).not_to be_empty
      end

      it 'parses bold text' do
        content = "* Heading\n\nText with *bold* word."
        parser = described_class.new(content)
        doc = parser.parse

        heading = doc.children.first
        para = heading.children.find { |c| c.is_a?(Markymark::Org::Nodes::Paragraph) }
        bold_nodes = para.children.select { |c| c.is_a?(Markymark::Org::Nodes::Bold) }
        expect(bold_nodes).not_to be_empty
      end

      it 'parses italic text' do
        content = "* Heading\n\nText with /italic/ word."
        parser = described_class.new(content)
        doc = parser.parse

        heading = doc.children.first
        para = heading.children.find { |c| c.is_a?(Markymark::Org::Nodes::Paragraph) }
        italic_nodes = para.children.select { |c| c.is_a?(Markymark::Org::Nodes::Italic) }
        expect(italic_nodes).not_to be_empty
      end

      it 'parses inline code' do
        content = "* Heading\n\nText with ~code~ here."
        parser = described_class.new(content)
        doc = parser.parse

        heading = doc.children.first
        para = heading.children.find { |c| c.is_a?(Markymark::Org::Nodes::Paragraph) }
        code_nodes = para.children.select { |c| c.is_a?(Markymark::Org::Nodes::Code) }
        expect(code_nodes).not_to be_empty
      end

      it 'parses links' do
        content = "* Heading\n\nA [[https://example.com][link]]."
        parser = described_class.new(content)
        doc = parser.parse

        heading = doc.children.first
        para = heading.children.find { |c| c.is_a?(Markymark::Org::Nodes::Paragraph) }
        link_nodes = para.children.select { |c| c.is_a?(Markymark::Org::Nodes::Link) }
        expect(link_nodes).not_to be_empty
        expect(link_nodes.first.url).to eq('https://example.com')
        expect(link_nodes.first.description).to eq('link')
      end
    end

    describe 'blocks' do
      it 'parses source blocks with language' do
        content = <<~ORG
          * Heading
          #+BEGIN_SRC ruby
          puts "hello"
          #+END_SRC
        ORG
        parser = described_class.new(content)
        doc = parser.parse

        heading = doc.children.first
        src_blocks = heading.children.select { |c| c.is_a?(Markymark::Org::Nodes::SrcBlock) }
        expect(src_blocks).not_to be_empty
        expect(src_blocks.first.language).to eq('ruby')
        expect(src_blocks.first.content).to include('puts')
      end

      it 'parses example blocks' do
        content = <<~ORG
          * Heading
          #+BEGIN_EXAMPLE
          Example content
          #+END_EXAMPLE
        ORG
        parser = described_class.new(content)
        doc = parser.parse

        heading = doc.children.first
        example_blocks = heading.children.select { |c| c.is_a?(Markymark::Org::Nodes::ExampleBlock) }
        expect(example_blocks).not_to be_empty
        expect(example_blocks.first.content).to include('Example content')
      end

      it 'parses quote blocks' do
        content = <<~ORG
          * Heading
          #+BEGIN_QUOTE
          A wise quote
          #+END_QUOTE
        ORG
        parser = described_class.new(content)
        doc = parser.parse

        heading = doc.children.first
        quote_blocks = heading.children.select { |c| c.is_a?(Markymark::Org::Nodes::QuoteBlock) }
        expect(quote_blocks).not_to be_empty
      end
    end

    describe 'tables' do
      it 'parses tables with header' do
        content = <<~ORG
          * Heading
          | Name | Age |
          |------+-----|
          | Bob  | 30  |
        ORG
        parser = described_class.new(content)
        doc = parser.parse

        heading = doc.children.first
        tables = heading.children.select { |c| c.is_a?(Markymark::Org::Nodes::Table) }
        expect(tables).not_to be_empty
      end

      it 'identifies header row' do
        content = <<~ORG
          * Heading
          | Name | Age |
          |------+-----|
          | Bob  | 30  |
        ORG
        parser = described_class.new(content)
        doc = parser.parse

        heading = doc.children.first
        table = heading.children.find { |c| c.is_a?(Markymark::Org::Nodes::Table) }
        header = table.header_row
        expect(header).not_to be_nil
        expect(header.header?).to be true
      end
    end

    describe 'lists' do
      it 'parses unordered lists' do
        content = <<~ORG
          * Heading
          - Item one
          - Item two
        ORG
        parser = described_class.new(content)
        doc = parser.parse

        heading = doc.children.first
        lists = heading.children.select { |c| c.is_a?(Markymark::Org::Nodes::List) }
        expect(lists).not_to be_empty
        expect(lists.first.ordered?).to be false
      end

      it 'parses ordered lists' do
        content = <<~ORG
          * Heading
          1. First
          2. Second
        ORG
        parser = described_class.new(content)
        doc = parser.parse

        heading = doc.children.first
        lists = heading.children.select { |c| c.is_a?(Markymark::Org::Nodes::List) }
        expect(lists).not_to be_empty
        expect(lists.first.ordered?).to be true
      end

      it 'parses checkbox items' do
        content = <<~ORG
          * Heading
          - [ ] Unchecked
          - [X] Checked
        ORG
        parser = described_class.new(content)
        doc = parser.parse

        heading = doc.children.first
        list = heading.children.find { |c| c.is_a?(Markymark::Org::Nodes::List) }
        items = list.children

        expect(items[0].checkbox_state).to eq(:unchecked)
        expect(items[1].checkbox_state).to eq(:checked)
      end
    end

    describe 'footnotes' do
      it 'parses footnote references' do
        content = "* Heading\n\nText with footnote[fn:1]."
        parser = described_class.new(content)
        doc = parser.parse

        heading = doc.children.first
        para = heading.children.find { |c| c.is_a?(Markymark::Org::Nodes::Paragraph) }
        fn_refs = para.children.select { |c| c.is_a?(Markymark::Org::Nodes::FootnoteRef) }
        expect(fn_refs).not_to be_empty
        expect(fn_refs.first.label).to eq('1')
      end

      it 'collects footnote definitions' do
        content = <<~ORG
          * Heading
          Text[fn:1].
          [fn:1] Footnote definition.
        ORG
        parser = described_class.new(content)
        doc = parser.parse

        fn_defs = doc.children.select { |c| c.is_a?(Markymark::Org::Nodes::FootnoteDef) }
        expect(fn_defs).not_to be_empty
        expect(fn_defs.first.label).to eq('1')
      end
    end
  end
end
