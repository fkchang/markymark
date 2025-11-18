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

      expect(html).to include('Error rendering markdown')
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
end
