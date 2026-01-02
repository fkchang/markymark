# frozen_string_literal: true

require 'spec_helper'
require 'markymark/server_simple'
require 'fileutils'
require 'tmpdir'

RSpec.describe Markymark::ServerSimple do
  describe '.group_files_by_directory' do
    it 'groups files by their directory' do
      files = [
        'README.md',
        'docs/guide.md',
        'docs/api.md',
        'notes/todo.md'
      ]

      result = described_class.group_files_by_directory(files)

      expect(result.keys).to eq(['.', 'docs', 'notes'])
      expect(result['.']).to eq(['README.md'])
      expect(result['docs']).to eq(['api.md', 'guide.md'])
      expect(result['notes']).to eq(['todo.md'])
    end

    it 'sorts directories with root first' do
      files = [
        'notes/todo.md',
        'README.md',
        'docs/guide.md'
      ]

      result = described_class.group_files_by_directory(files)

      expect(result.keys.first).to eq('.')
    end

    it 'sorts files within each directory' do
      files = [
        'docs/zebra.md',
        'docs/alpha.md',
        'docs/beta.md'
      ]

      result = described_class.group_files_by_directory(files)

      expect(result['docs']).to eq(['alpha.md', 'beta.md', 'zebra.md'])
    end

    it 'handles empty file list' do
      result = described_class.group_files_by_directory([])

      expect(result).to eq({})
    end
  end

  describe '.find_markdown_files' do
    around do |example|
      Dir.mktmpdir do |dir|
        @test_dir = dir
        example.run
      end
    end

    it 'finds .md files' do
      File.write(File.join(@test_dir, 'test.md'), '# Test')
      File.write(File.join(@test_dir, 'readme.md'), '# Readme')

      files = described_class.find_markdown_files(@test_dir)

      expect(files).to contain_exactly('readme.md', 'test.md')
    end

    it 'finds .markdown files' do
      File.write(File.join(@test_dir, 'test.markdown'), '# Test')

      files = described_class.find_markdown_files(@test_dir)

      expect(files).to include('test.markdown')
    end

    it 'finds files recursively' do
      subdir = File.join(@test_dir, 'docs')
      FileUtils.mkdir_p(subdir)
      File.write(File.join(subdir, 'guide.md'), '# Guide')

      files = described_class.find_markdown_files(@test_dir)

      expect(files).to include('docs/guide.md')
    end

    it 'ignores non-markdown files' do
      File.write(File.join(@test_dir, 'test.txt'), 'Text')
      File.write(File.join(@test_dir, 'test.md'), '# Test')

      files = described_class.find_markdown_files(@test_dir)

      expect(files).to eq(['test.md'])
    end

    it 'handles case-insensitive matching' do
      File.write(File.join(@test_dir, 'TEST.MD'), '# Test')
      File.write(File.join(@test_dir, 'readme.MARKDOWN'), '# Readme')

      files = described_class.find_markdown_files(@test_dir)

      expect(files.size).to eq(2)
    end

    it 'returns empty array for empty directory' do
      files = described_class.find_markdown_files(@test_dir)

      expect(files).to eq([])
    end
  end

  describe '.render_markdown' do
    around do |example|
      Dir.mktmpdir do |dir|
        @test_dir = dir
        described_class.root_path = @test_dir
        described_class.real_root_path = File.realpath(@test_dir)
        example.run
      end
    end

    it 'renders basic markdown to HTML' do
      File.write(File.join(@test_dir, 'test.md'), '# Hello World')

      html = described_class.render_markdown('test.md', @test_dir)

      expect(html).to include('<h1')
      expect(html).to include('Hello World')
    end

    it 'renders GitHub-flavored markdown tables' do
      markdown = <<~MD
        | Header 1 | Header 2 |
        |----------|----------|
        | Cell 1   | Cell 2   |
      MD
      File.write(File.join(@test_dir, 'table.md'), markdown)

      html = described_class.render_markdown('table.md', @test_dir)

      expect(html).to include('<table')
      expect(html).to include('<th')
      expect(html).to include('Header 1')
    end

    it 'converts mermaid code blocks to divs' do
      markdown = <<~MD
        ```mermaid
        graph TD
          A --> B
        ```
      MD
      File.write(File.join(@test_dir, 'diagram.md'), markdown)

      html = described_class.render_markdown('diagram.md', @test_dir)

      expect(html).to include('<div class="mermaid">')
      expect(html).to include('graph TD')
      expect(html).not_to include('<code class="language-mermaid">')
    end

    it 'returns nil for non-existent file' do
      result = described_class.render_markdown('nonexistent.md', @test_dir)

      expect(result).to be_nil
    end

    it 'handles rendering errors gracefully' do
      # Create a file that exists but can't be read (simulate error)
      File.write(File.join(@test_dir, 'test.md'), '# Test')

      # Stub File.read to raise an error
      allow(File).to receive(:read).and_raise(StandardError.new('Read error'))

      html = described_class.render_markdown('test.md', @test_dir)

      expect(html).to include('Error rendering document')
      expect(html).to include('Read error')
    end
  end

  describe '.within_root?' do
    around do |example|
      Dir.mktmpdir do |dir|
        @test_root = File.realpath(dir)
        example.run
      end
    end

    it 'returns true for path within root' do
      test_path = File.join(@test_root, 'subdir', 'file.md')

      result = described_class.within_root?(test_path, @test_root)

      expect(result).to be true
    end

    it 'returns true for path equal to root' do
      result = described_class.within_root?(@test_root, @test_root)

      expect(result).to be true
    end

    it 'returns false for path outside root' do
      other_path = '/tmp/other/file.md'

      result = described_class.within_root?(other_path, @test_root)

      expect(result).to be false
    end

    it 'returns false for nil path' do
      result = described_class.within_root?(nil, @test_root)

      expect(result).to be false
    end

    it 'returns false for nil root' do
      test_path = File.join(@test_root, 'file.md')

      result = described_class.within_root?(test_path, nil)

      expect(result).to be false
    end

    it 'prevents path traversal attacks' do
      # Attempt to escape with ../
      malicious_path = File.join(@test_root, '..', 'etc', 'passwd')
      real_malicious = File.realpath(File.join(@test_root, '..'))

      result = described_class.within_root?(real_malicious, @test_root)

      expect(result).to be false
    end
  end

  describe 'bookmark management' do
    let(:temp_dir) { Dir.mktmpdir }
    let(:bookmark_file) { File.join(temp_dir, 'bookmarks.json') }

    before do
      allow(described_class).to receive(:bookmarks_file).and_return(bookmark_file)
    end

    after do
      FileUtils.rm_rf(temp_dir)
    end

    describe '.load_bookmarks' do
      it 'returns empty array when file does not exist' do
        bookmarks = described_class.load_bookmarks

        expect(bookmarks).to eq([])
      end

      it 'loads bookmarks from JSON file' do
        bookmarks_data = [
          { 'name' => 'Docs', 'path' => '/path/to/docs' },
          { 'name' => 'Notes', 'path' => '/path/to/notes' }
        ]
        File.write(bookmark_file, JSON.generate(bookmarks_data))

        bookmarks = described_class.load_bookmarks

        expect(bookmarks).to eq(bookmarks_data)
      end

      it 'returns empty array on JSON parse error' do
        File.write(bookmark_file, 'invalid json')

        bookmarks = described_class.load_bookmarks

        expect(bookmarks).to eq([])
      end
    end

    describe '.save_bookmarks' do
      it 'creates directory if it does not exist' do
        bookmarks = [{ 'name' => 'Test', 'path' => '/test' }]

        described_class.save_bookmarks(bookmarks)

        expect(File.directory?(File.dirname(bookmark_file))).to be true
      end

      it 'saves bookmarks to JSON file' do
        bookmarks = [
          { 'name' => 'Docs', 'path' => '/path/to/docs' }
        ]

        described_class.save_bookmarks(bookmarks)

        saved_data = JSON.parse(File.read(bookmark_file))
        expect(saved_data).to eq(bookmarks)
      end

      it 'formats JSON with pretty print' do
        bookmarks = [{ 'name' => 'Test', 'path' => '/test' }]

        described_class.save_bookmarks(bookmarks)

        content = File.read(bookmark_file)
        expect(content).to include("\n")
        expect(content).to include("  ")
      end
    end

    describe '.add_bookmark' do
      it 'adds bookmark to empty list' do
        described_class.add_bookmark('Docs', '/path/to/docs')

        bookmarks = described_class.load_bookmarks
        expect(bookmarks.size).to eq(1)
        expect(bookmarks.first['name']).to eq('Docs')
        expect(bookmarks.first['path']).to eq('/path/to/docs')
      end

      it 'appends bookmark to existing list' do
        described_class.add_bookmark('First', '/first')
        described_class.add_bookmark('Second', '/second')

        bookmarks = described_class.load_bookmarks
        expect(bookmarks.size).to eq(2)
        expect(bookmarks.map { |b| b['name'] }).to eq(['First', 'Second'])
      end

      it 'prevents duplicate paths' do
        described_class.add_bookmark('Docs', '/path/to/docs')
        described_class.add_bookmark('Docs Copy', '/path/to/docs')

        bookmarks = described_class.load_bookmarks
        expect(bookmarks.size).to eq(1)
      end
    end

    describe '.remove_bookmark' do
      it 'removes bookmark at specified index' do
        described_class.add_bookmark('First', '/first')
        described_class.add_bookmark('Second', '/second')
        described_class.add_bookmark('Third', '/third')

        described_class.remove_bookmark(1)

        bookmarks = described_class.load_bookmarks
        expect(bookmarks.size).to eq(2)
        expect(bookmarks.map { |b| b['name'] }).to eq(['First', 'Third'])
      end

      it 'handles string index' do
        described_class.add_bookmark('First', '/first')
        described_class.add_bookmark('Second', '/second')

        described_class.remove_bookmark('0')

        bookmarks = described_class.load_bookmarks
        expect(bookmarks.size).to eq(1)
        expect(bookmarks.first['name']).to eq('Second')
      end

      it 'does nothing for invalid index' do
        described_class.add_bookmark('First', '/first')

        described_class.remove_bookmark(99)

        bookmarks = described_class.load_bookmarks
        expect(bookmarks.size).to eq(1)
      end
    end
  end

  describe '.rewrite_markdown_links' do
    let(:root_path) { '/test/root' }

    it 'rewrites simple relative markdown links' do
      html = '<a href="guide.md">Guide</a>'
      result = described_class.rewrite_markdown_links(html, 'README.md', root_path)

      expect(result).to include('href="/?file=guide.md&dir=%2Ftest%2Froot"')
      expect(result).to include('>Guide</a>')
    end

    it 'rewrites nested relative markdown links' do
      html = '<a href="docs/api.md">API</a>'
      result = described_class.rewrite_markdown_links(html, 'README.md', root_path)

      expect(result).to include('href="/?file=docs%2Fapi.md&dir=%2Ftest%2Froot"')
    end

    it 'resolves links relative to current file directory' do
      html = '<a href="advanced.md">Advanced</a>'
      result = described_class.rewrite_markdown_links(html, 'docs/getting-started.md', root_path)

      expect(result).to include('href="/?file=docs%2Fadvanced.md&dir=%2Ftest%2Froot"')
    end

    it 'handles parent directory references' do
      html = '<a href="../README.md">Home</a>'
      result = described_class.rewrite_markdown_links(html, 'docs/guide.md', root_path)

      expect(result).to include('href="/?file=README.md&dir=%2Ftest%2Froot"')
    end

    it 'preserves absolute URLs unchanged' do
      html = '<a href="https://example.com/doc.md">External</a>'
      result = described_class.rewrite_markdown_links(html, 'README.md', root_path)

      expect(result).to eq(html)
    end

    it 'preserves protocol-relative URLs unchanged' do
      html = '<a href="//example.com/doc.md">External</a>'
      result = described_class.rewrite_markdown_links(html, 'README.md', root_path)

      expect(result).to eq(html)
    end

    it 'preserves anchor links unchanged' do
      html = '<a href="#section">Section</a>'
      result = described_class.rewrite_markdown_links(html, 'README.md', root_path)

      expect(result).to eq(html)
    end

    it 'rewrites non-markdown file links to use /doc/ route' do
      html = '<a href="image.png">Image</a>'
      result = described_class.rewrite_markdown_links(html, 'README.md', root_path)

      expect(result).to include('href="/doc/image.png?dir=%2Ftest%2Froot"')
    end

    it 'rewrites relative image links from nested files' do
      html = '<a href="./screenshot.png">Screenshot</a>'
      result = described_class.rewrite_markdown_links(html, 'docs/guide/README.md', root_path)

      expect(result).to include('href="/doc/docs%2Fguide%2Fscreenshot.png?dir=%2Ftest%2Froot"')
    end

    it 'rewrites img src attributes' do
      html = '<img src="diagram.png" alt="Diagram">'
      result = described_class.rewrite_markdown_links(html, 'docs/README.md', root_path)

      expect(result).to include('src="/doc/docs%2Fdiagram.png?dir=%2Ftest%2Froot"')
    end

    it 'preserves absolute URLs in img tags' do
      html = '<img src="https://example.com/image.png">'
      result = described_class.rewrite_markdown_links(html, 'README.md', root_path)

      expect(result).to eq(html)
    end

    it 'preserves link attributes' do
      html = '<a href="guide.md" class="link" target="_blank">Guide</a>'
      result = described_class.rewrite_markdown_links(html, 'README.md', root_path)

      expect(result).to include('class="link" target="_blank"')
    end

    it 'handles .markdown extension' do
      html = '<a href="docs/guide.markdown">Guide</a>'
      result = described_class.rewrite_markdown_links(html, 'README.md', root_path)

      expect(result).to include('href="/?file=docs%2Fguide.markdown&dir=%2Ftest%2Froot"')
    end

    it 'handles case-insensitive markdown extensions' do
      html = '<a href="guide.MD">Guide</a>'
      result = described_class.rewrite_markdown_links(html, 'README.md', root_path)

      expect(result).to include('href="/?file=guide.MD&dir=%2Ftest%2Froot"')
    end

    it 'handles multiple links in same HTML' do
      html = '<a href="guide.md">Guide</a> and <a href="api.md">API</a>'
      result = described_class.rewrite_markdown_links(html, 'README.md', root_path)

      expect(result).to include('href="/?file=guide.md&dir=%2Ftest%2Froot"')
      expect(result).to include('href="/?file=api.md&dir=%2Ftest%2Froot"')
    end

    it 'preserves mailto links unchanged' do
      html = '<a href="mailto:test@example.com">Email</a>'
      result = described_class.rewrite_markdown_links(html, 'README.md', root_path)

      expect(result).to eq(html)
    end
  end

  describe '.resolve_editor' do
    before do
      # Clear all editor-related env vars
      @saved_env = {}
      %w[MARKYMARK_EDITOR_MD MARKYMARK_EDITOR_ORG MARKYMARK_EDITOR VISUAL EDITOR].each do |var|
        @saved_env[var] = ENV[var]
        ENV.delete(var)
      end
    end

    after do
      # Restore env vars
      @saved_env.each do |var, value|
        if value
          ENV[var] = value
        else
          ENV.delete(var)
        end
      end
    end

    it 'returns filetype-specific editor when set' do
      ENV['MARKYMARK_EDITOR_ORG'] = 'emacs'
      ENV['MARKYMARK_EDITOR'] = 'code'

      expect(described_class.resolve_editor('.org')).to eq('emacs')
    end

    it 'returns MARKYMARK_EDITOR when filetype-specific not set' do
      ENV['MARKYMARK_EDITOR'] = 'code'
      ENV['VISUAL'] = 'vim'

      expect(described_class.resolve_editor('.md')).to eq('code')
    end

    it 'returns VISUAL when MARKYMARK_EDITOR not set' do
      ENV['VISUAL'] = 'vim'
      ENV['EDITOR'] = 'nano'

      expect(described_class.resolve_editor('.md')).to eq('vim')
    end

    it 'returns EDITOR when VISUAL not set' do
      ENV['EDITOR'] = 'nano'

      expect(described_class.resolve_editor('.md')).to eq('nano')
    end

    it 'returns platform default when no env vars set' do
      result = described_class.resolve_editor('.md')

      # On macOS this should be 'open'
      expect(['open', 'xdg-open', 'start']).to include(result)
    end

    it 'handles uppercase extension in env var lookup' do
      ENV['MARKYMARK_EDITOR_MD'] = 'typora'

      expect(described_class.resolve_editor('.md')).to eq('typora')
    end

    it 'skips empty env vars' do
      ENV['MARKYMARK_EDITOR'] = ''
      ENV['VISUAL'] = 'vim'

      expect(described_class.resolve_editor('.md')).to eq('vim')
    end
  end
end
