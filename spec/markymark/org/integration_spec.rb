# frozen_string_literal: true

require 'spec_helper'
require 'markymark'
require 'tmpdir'
require 'fileutils'

RSpec.describe 'Org-mode integration with ServerSimple' do
  around do |example|
    Dir.mktmpdir do |dir|
      @test_dir = dir
      example.run
    end
  end

  describe '.render_markdown with org files' do
    it 'renders .org files' do
      File.write(File.join(@test_dir, 'test.org'), '* Hello Org')

      html = Markymark::ServerSimple.render_markdown('test.org', @test_dir)

      expect(html).to include('<h1')
      expect(html).to include('Hello Org')
    end

    it 'renders .md files as before' do
      File.write(File.join(@test_dir, 'test.md'), '# Hello Markdown')

      html = Markymark::ServerSimple.render_markdown('test.md', @test_dir)

      expect(html).to include('<h1')
      expect(html).to include('Hello Markdown')
    end

    it 'routes based on file extension' do
      File.write(File.join(@test_dir, 'test.org'), '* Org Heading')

      html = Markymark::ServerSimple.render_markdown('test.org', @test_dir)

      expect(html).to include('class="org-heading"')
      expect(html).to include('data-org-level')
    end
  end

  describe '.find_markdown_files' do
    it 'includes org files in results' do
      File.write(File.join(@test_dir, 'doc.org'), '* Org Doc')
      File.write(File.join(@test_dir, 'doc.md'), '# MD Doc')

      files = Markymark::ServerSimple.find_markdown_files(@test_dir)

      expect(files).to include('doc.org')
      expect(files).to include('doc.md')
    end

    it 'finds org files in subdirectories' do
      subdir = File.join(@test_dir, 'subdir')
      FileUtils.mkdir_p(subdir)
      File.write(File.join(subdir, 'nested.org'), '* Nested')

      files = Markymark::ServerSimple.find_markdown_files(@test_dir)

      expect(files).to include('subdir/nested.org')
    end
  end

  describe 'full org file rendering' do
    let(:fixture_path) { File.expand_path('../../../fixtures/sample.org', __FILE__) }
    let(:fixture_content) { File.read(fixture_path) }

    it 'renders the fixture file without errors' do
      html = Markymark::Org.to_html(fixture_content)

      expect(html).to be_a(String)
      expect(html.length).to be > 0
    end

    it 'renders headings with TODO states' do
      html = Markymark::Org.to_html(fixture_content)

      expect(html).to include('org-todo-todo')
      expect(html).to include('org-todo-done')
    end

    it 'renders headings with tags' do
      html = Markymark::Org.to_html(fixture_content)

      expect(html).to include('org-tag')
      expect(html).to include('tag1')
      expect(html).to include('tag2')
    end

    it 'renders properties drawer with CUSTOM_ID' do
      html = Markymark::Org.to_html(fixture_content)

      expect(html).to include('id="custom-first"')
      expect(html).to include('org-properties')
    end

    it 'renders links' do
      html = Markymark::Org.to_html(fixture_content)

      expect(html).to include('href="https://example.com"')
      expect(html).to include('Example Site')
    end

    it 'renders named source blocks with caption' do
      html = Markymark::Org.to_html(fixture_content)

      expect(html).to include('org-src-block')
      expect(html).to include('id="block-my-code-block"')
      expect(html).to include('my-code-block')
    end

    it 'renders tables' do
      html = Markymark::Org.to_html(fixture_content)

      expect(html).to include('org-table')
      expect(html).to include('<th>')
      expect(html).to include('Alice')
    end

    it 'renders footnotes with linking' do
      html = Markymark::Org.to_html(fixture_content)

      expect(html).to include('fnref-1')
      expect(html).to include('fn-1')
      expect(html).to include('org-footnote-backref')
    end

    it 'generates stable IDs for headings' do
      # Render twice and verify same IDs
      html1 = Markymark::Org.to_html(fixture_content)
      html2 = Markymark::Org.to_html(fixture_content)

      # Extract heading IDs
      ids1 = html1.scan(/id="([^"]+)"/).flatten
      ids2 = html2.scan(/id="([^"]+)"/).flatten

      expect(ids1).to eq(ids2)
    end
  end
end
