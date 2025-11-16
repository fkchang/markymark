# frozen_string_literal: true

require 'listen'
require 'pathname'

module Markymark
  # Watches filesystem for markdown file changes
  class Watcher
    MARKDOWN_EXTENSIONS = ['.md', '.markdown'].freeze

    attr_reader :root_path, :listener

    def initialize(root_path, server)
      @root_path = root_path
      @server = server
      @listener = nil
    end

    def start
      @listener = Listen.to(@root_path) do |modified, added, removed|
        handle_changes(modified, added, removed)
      end

      @listener.start
    end

    def stop
      @listener&.stop
    end

    private

    def handle_changes(modified, added, removed)
      md_modified = filter_markdown(modified)
      md_added = filter_markdown(added)
      md_removed = filter_markdown(removed)

      return if md_modified.empty? && md_added.empty? && md_removed.empty?

      # Broadcast file content changes for currently viewed files
      md_modified.each do |file_path|
        relative_path = relative_to_root(file_path)
        @server.broadcast_file_changed(relative_path)
      end

      # Broadcast tree updates if files were added or removed
      if md_added.any? || md_removed.any?
        @server.broadcast_tree_updated
      end
    end

    def filter_markdown(paths)
      paths.select { |path| markdown_file?(path) }
    end

    def markdown_file?(path)
      ext = File.extname(path).downcase
      MARKDOWN_EXTENSIONS.include?(ext)
    end

    def relative_to_root(absolute_path)
      Pathname.new(absolute_path).relative_path_from(Pathname.new(@root_path)).to_s
    end
  end
end
