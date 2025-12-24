# frozen_string_literal: true

require 'spec_helper'
require 'markymark'

RSpec.describe Markymark::Org::Renderer do
  let(:id_generator) { Markymark::Org::IdGenerator.new }
  let(:renderer) { described_class.new(id_generator: id_generator) }

  describe '#render' do
    describe 'document' do
      it 'renders document title when present' do
        doc = Markymark::Org::Nodes::Document.new(
          children: [],
          title: 'My Document'
        )

        html = renderer.render(doc)

        expect(html).to include('class="org-document-title"')
        expect(html).to include('My Document')
      end
    end

    describe 'headings' do
      it 'wraps headings in sections with data-org-level' do
        heading = Markymark::Org::Nodes::Heading.new(
          level: 2,
          text: 'Test Heading',
          children: []
        )
        doc = Markymark::Org::Nodes::Document.new(children: [heading])

        html = renderer.render(doc)

        expect(html).to include('data-org-level="2"')
        expect(html).to include('<h2')
        expect(html).to include('</h2>')
      end

      it 'generates stable IDs for headings' do
        heading = Markymark::Org::Nodes::Heading.new(
          level: 1,
          text: 'My Heading',
          children: []
        )
        doc = Markymark::Org::Nodes::Document.new(children: [heading])

        html = renderer.render(doc)

        expect(html).to include('id="my-heading"')
      end

      it 'uses CUSTOM_ID when present' do
        heading = Markymark::Org::Nodes::Heading.new(
          level: 1,
          text: 'Heading',
          custom_id: 'my-custom-id',
          children: []
        )
        doc = Markymark::Org::Nodes::Document.new(children: [heading])

        html = renderer.render(doc)

        expect(html).to include('id="my-custom-id"')
      end

      it 'renders TODO state badge' do
        heading = Markymark::Org::Nodes::Heading.new(
          level: 1,
          text: 'Task',
          todo_state: 'TODO',
          children: []
        )
        doc = Markymark::Org::Nodes::Document.new(children: [heading])

        html = renderer.render(doc)

        expect(html).to include('class="org-todo org-todo-todo"')
        expect(html).to include('TODO')
      end

      it 'renders tags' do
        heading = Markymark::Org::Nodes::Heading.new(
          level: 1,
          text: 'Heading',
          tags: ['tag1', 'tag2'],
          children: []
        )
        doc = Markymark::Org::Nodes::Document.new(children: [heading])

        html = renderer.render(doc)

        expect(html).to include('class="org-tags"')
        expect(html).to include('class="org-tag"')
        expect(html).to include('tag1')
        expect(html).to include('tag2')
      end

      it 'renders properties drawer' do
        heading = Markymark::Org::Nodes::Heading.new(
          level: 1,
          text: 'Heading',
          properties_drawer: { 'KEY' => 'value', 'OTHER' => 'data' },
          children: []
        )
        doc = Markymark::Org::Nodes::Document.new(children: [heading])

        html = renderer.render(doc)

        expect(html).to include('class="org-properties"')
        expect(html).to include('<dt>KEY</dt>')
        expect(html).to include('<dd>value</dd>')
      end
    end

    describe 'paragraphs and inline' do
      it 'renders paragraphs' do
        para = Markymark::Org::Nodes::Paragraph.new(
          children: [Markymark::Org::Nodes::Text.new(content: 'Hello world')]
        )
        doc = Markymark::Org::Nodes::Document.new(children: [para])

        html = renderer.render(doc)

        expect(html).to include('<p>Hello world</p>')
      end

      it 'renders bold text' do
        bold = Markymark::Org::Nodes::Bold.new(
          children: [Markymark::Org::Nodes::Text.new(content: 'bold')]
        )
        para = Markymark::Org::Nodes::Paragraph.new(children: [bold])
        doc = Markymark::Org::Nodes::Document.new(children: [para])

        html = renderer.render(doc)

        expect(html).to include('<strong>bold</strong>')
      end

      it 'renders italic text' do
        italic = Markymark::Org::Nodes::Italic.new(
          children: [Markymark::Org::Nodes::Text.new(content: 'italic')]
        )
        para = Markymark::Org::Nodes::Paragraph.new(children: [italic])
        doc = Markymark::Org::Nodes::Document.new(children: [para])

        html = renderer.render(doc)

        expect(html).to include('<em>italic</em>')
      end

      it 'renders inline code' do
        code = Markymark::Org::Nodes::Code.new(content: 'code')
        para = Markymark::Org::Nodes::Paragraph.new(children: [code])
        doc = Markymark::Org::Nodes::Document.new(children: [para])

        html = renderer.render(doc)

        expect(html).to include('<code>code</code>')
      end

      it 'renders external links' do
        link = Markymark::Org::Nodes::Link.new(
          url: 'https://example.com',
          description: 'Example'
        )
        para = Markymark::Org::Nodes::Paragraph.new(children: [link])
        doc = Markymark::Org::Nodes::Document.new(children: [para])

        html = renderer.render(doc)

        expect(html).to include('href="https://example.com"')
        expect(html).to include('>Example</a>')
        expect(html).to include('class="org-external-link"')
      end

      it 'renders internal heading links' do
        link = Markymark::Org::Nodes::Link.new(
          url: nil,
          anchor_type: :heading,
          anchor_value: 'Introduction',
          description: 'See Intro'
        )
        para = Markymark::Org::Nodes::Paragraph.new(children: [link])
        doc = Markymark::Org::Nodes::Document.new(children: [para])

        html = renderer.render(doc)

        expect(html).to include('href="#introduction"')
        expect(html).to include('>See Intro</a>')
        expect(html).to include('class="org-internal-link"')
      end

      it 'renders cross-document links with heading anchors' do
        link = Markymark::Org::Nodes::Link.new(
          url: 'file:other.org',
          anchor_type: :heading,
          anchor_value: 'Getting Started',
          description: nil
        )
        para = Markymark::Org::Nodes::Paragraph.new(children: [link])
        doc = Markymark::Org::Nodes::Document.new(children: [para])

        html = renderer.render(doc)

        expect(html).to include('href="other.org#getting-started"')
        expect(html).to include('class="org-cross-doc-link"')
      end

      it 'escapes HTML in text' do
        text = Markymark::Org::Nodes::Text.new(content: '<script>alert("xss")</script>')
        para = Markymark::Org::Nodes::Paragraph.new(children: [text])
        doc = Markymark::Org::Nodes::Document.new(children: [para])

        html = renderer.render(doc)

        expect(html).not_to include('<script>')
        expect(html).to include('&lt;script&gt;')
      end
    end

    describe 'blocks' do
      it 'renders source blocks with syntax highlighting' do
        src = Markymark::Org::Nodes::SrcBlock.new(
          content: 'puts "hello"',
          language: 'ruby'
        )
        doc = Markymark::Org::Nodes::Document.new(children: [src])

        html = renderer.render(doc)

        expect(html).to include('class="org-src-block"')
        expect(html).to include('class="highlight"')  # Rouge highlighting class
        expect(html).to include('puts')  # Content is present (may have spans for highlighting)
      end

      it 'renders named source blocks with caption and ID' do
        src = Markymark::Org::Nodes::SrcBlock.new(
          content: 'code',
          language: 'ruby',
          name: 'my-block'
        )
        doc = Markymark::Org::Nodes::Document.new(children: [src])

        html = renderer.render(doc)

        expect(html).to include('id="block-my-block"')
        expect(html).to include('<figcaption>my-block</figcaption>')
      end

      it 'renders example blocks' do
        example = Markymark::Org::Nodes::ExampleBlock.new(content: 'example text')
        doc = Markymark::Org::Nodes::Document.new(children: [example])

        html = renderer.render(doc)

        expect(html).to include('class="org-example-block"')
        expect(html).to include('example text')
      end

      it 'renders quote blocks' do
        para = Markymark::Org::Nodes::Paragraph.new(
          children: [Markymark::Org::Nodes::Text.new(content: 'Quote text')]
        )
        quote = Markymark::Org::Nodes::QuoteBlock.new(children: [para])
        doc = Markymark::Org::Nodes::Document.new(children: [quote])

        html = renderer.render(doc)

        expect(html).to include('class="org-quote-block"')
        expect(html).to include('Quote text')
      end
    end

    describe 'tables' do
      it 'renders tables with structure' do
        header_cells = [
          Markymark::Org::Nodes::TableCell.new(content: 'Name', children: []),
          Markymark::Org::Nodes::TableCell.new(content: 'Age', children: [])
        ]
        header_row = Markymark::Org::Nodes::TableRow.new(children: header_cells, header: true)

        data_cells = [
          Markymark::Org::Nodes::TableCell.new(content: 'Alice', children: []),
          Markymark::Org::Nodes::TableCell.new(content: '30', children: [])
        ]
        data_row = Markymark::Org::Nodes::TableRow.new(children: data_cells)

        table = Markymark::Org::Nodes::Table.new(children: [header_row, data_row])
        doc = Markymark::Org::Nodes::Document.new(children: [table])

        html = renderer.render(doc)

        expect(html).to include('class="org-table"')
        expect(html).to include('<thead>')
        expect(html).to include('<th>Name</th>')
        expect(html).to include('<tbody>')
        expect(html).to include('<td>Alice</td>')
      end
    end

    describe 'lists' do
      it 'renders unordered lists' do
        item1 = Markymark::Org::Nodes::ListItem.new(
          children: [Markymark::Org::Nodes::Paragraph.new(
            children: [Markymark::Org::Nodes::Text.new(content: 'Item 1')]
          )]
        )
        item2 = Markymark::Org::Nodes::ListItem.new(
          children: [Markymark::Org::Nodes::Paragraph.new(
            children: [Markymark::Org::Nodes::Text.new(content: 'Item 2')]
          )]
        )
        list = Markymark::Org::Nodes::List.new(children: [item1, item2], ordered: false)
        doc = Markymark::Org::Nodes::Document.new(children: [list])

        html = renderer.render(doc)

        expect(html).to include('<ul>')
        expect(html).to include('<li>')
        expect(html).to include('Item 1')
      end

      it 'renders ordered lists' do
        item = Markymark::Org::Nodes::ListItem.new(
          children: [Markymark::Org::Nodes::Paragraph.new(
            children: [Markymark::Org::Nodes::Text.new(content: 'First')]
          )]
        )
        list = Markymark::Org::Nodes::List.new(children: [item], ordered: true)
        doc = Markymark::Org::Nodes::Document.new(children: [list])

        html = renderer.render(doc)

        expect(html).to include('<ol>')
      end

      it 'renders checkbox items' do
        unchecked = Markymark::Org::Nodes::ListItem.new(
          checkbox_state: :unchecked,
          children: [Markymark::Org::Nodes::Paragraph.new(
            children: [Markymark::Org::Nodes::Text.new(content: 'Unchecked')]
          )]
        )
        checked = Markymark::Org::Nodes::ListItem.new(
          checkbox_state: :checked,
          children: [Markymark::Org::Nodes::Paragraph.new(
            children: [Markymark::Org::Nodes::Text.new(content: 'Checked')]
          )]
        )
        list = Markymark::Org::Nodes::List.new(children: [unchecked, checked], ordered: false)
        doc = Markymark::Org::Nodes::Document.new(children: [list])

        html = renderer.render(doc)

        expect(html).to include('type="checkbox"')
        expect(html).to include('checked')
        expect(html).to include('disabled')
      end
    end

    describe 'footnotes' do
      it 'renders footnote references with links' do
        fn_ref = Markymark::Org::Nodes::FootnoteRef.new(label: '1')
        para = Markymark::Org::Nodes::Paragraph.new(children: [fn_ref])
        doc = Markymark::Org::Nodes::Document.new(children: [para])

        html = renderer.render(doc)

        expect(html).to include('<sup')
        expect(html).to include('href="#fn-1"')
        expect(html).to include('[1]')
      end

      it 'renders footnote definitions with backlinks' do
        fn_def = Markymark::Org::Nodes::FootnoteDef.new(
          label: '1',
          children: [Markymark::Org::Nodes::Paragraph.new(
            children: [Markymark::Org::Nodes::Text.new(content: 'Footnote text')]
          )]
        )
        doc = Markymark::Org::Nodes::Document.new(children: [fn_def])

        html = renderer.render(doc)

        expect(html).to include('class="org-footnote-def"')
        expect(html).to include('id="fn-1"')
        expect(html).to include('[1]')
        expect(html).to include('class="org-footnote-backref"')
        expect(html).to include('Footnote text')
      end
    end

    describe 'other elements' do
      it 'renders horizontal rules' do
        hr = Markymark::Org::Nodes::HorizontalRule.new
        doc = Markymark::Org::Nodes::Document.new(children: [hr])

        html = renderer.render(doc)

        expect(html).to include('<hr>')
      end

      it 'renders raw/unsupported content with comment' do
        raw = Markymark::Org::Nodes::Raw.new(
          content: 'Unsupported content',
          original_type: 'custom-block'
        )
        doc = Markymark::Org::Nodes::Document.new(children: [raw])

        html = renderer.render(doc)

        expect(html).to include('<!-- Unsupported org-mode construct')
        expect(html).to include('class="org-raw"')
      end
    end
  end
end
