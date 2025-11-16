# frozen_string_literal: true

module Markymark
  # Scans directory for markdown files and builds tree structure
  class FileTree
    MARKDOWN_EXTENSIONS = ['.md', '.markdown'].freeze

    attr_reader :root_path

    def initialize(root_path)
      @root_path = File.expand_path(root_path)
      raise ArgumentError, "Directory not found: #{root_path}" unless File.directory?(@root_path)
    end

    # Returns array of all markdown file paths relative to root
    def markdown_files
      Dir.glob("**/*", base: root_path).select do |path|
        full_path = File.join(root_path, path)
        File.file?(full_path) && markdown_file?(path)
      end.sort
    end

    # Builds tree structure for JSON serialization
    # Returns: { name: "root", type: "folder", children: [...] }
    def build_tree
      files = markdown_files
      tree = { name: File.basename(root_path), type: 'folder', path: '', children: [] }

      files.each do |file_path|
        parts = file_path.split(File::SEPARATOR)
        current = tree

        parts.each_with_index do |part, index|
          is_last = index == parts.length - 1

          if is_last
            # It's a file
            current[:children] << {
              name: part,
              type: 'file',
              path: file_path
            }
          else
            # It's a folder - find or create it
            folder = current[:children].find { |child| child[:name] == part && child[:type] == 'folder' }

            unless folder
              folder = {
                name: part,
                type: 'folder',
                path: parts[0..index].join(File::SEPARATOR),
                children: []
              }
              current[:children] << folder
            end

            current = folder
          end
        end
      end

      # Sort children: folders first, then files, both alphabetically
      sort_tree!(tree)
      tree
    end

    # Find first file (README.md preferred, otherwise first alphabetically)
    def default_file
      files = markdown_files
      return nil if files.empty?

      # Look for README.md (case-insensitive) in root
      readme = files.find { |f| f.match?(/\AREADME\.md\z/i) }
      return readme if readme

      # Otherwise return first file
      files.first
    end

    private

    def markdown_file?(path)
      ext = File.extname(path).downcase
      MARKDOWN_EXTENSIONS.include?(ext)
    end

    def sort_tree!(node)
      return unless node[:children]

      node[:children].sort_by! { |child| [child[:type] == 'file' ? 1 : 0, child[:name].downcase] }
      node[:children].each { |child| sort_tree!(child) if child[:type] == 'folder' }
    end
  end
end
