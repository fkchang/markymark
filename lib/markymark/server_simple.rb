# frozen_string_literal: true

require 'sinatra/base'
require 'json'
require 'kramdown'
require 'rouge'
require 'launchy'
require 'pathname'
require 'fileutils'
require 'cgi'

module Markymark
  # Bulletproof simple Sinatra server for markdown browsing
  # No SSE, no watcher, no threading, no JavaScript complexity
  class ServerSimple < Sinatra::Base
    set :public_folder, File.join(File.dirname(__FILE__), '..', 'public')
    set :views, File.join(File.dirname(__FILE__), '..', 'views')
    set :server, :puma
    set :bind, '0.0.0.0'

    # Disable static file caching in development
    configure :development do
      set :static_cache_control, [:no_cache, :no_store, :must_revalidate]
    end

    class << self
      attr_accessor :root_path, :real_root_path

      def launch(cli)
        @root_path = cli.root_path
        @real_root_path = File.realpath(@root_path)

        # Print startup message
        base_url = "http://localhost:#{cli.port}"
        puts "markymark serving #{@root_path} on #{base_url}"

        # Build URL with optional file parameter
        url = if cli.initial_file
          "#{base_url}/?file=#{CGI.escape(cli.initial_file)}"
        else
          base_url
        end

        # Open browser if requested (before forking)
        Launchy.open(url) if cli.open_browser

        # Fork the process to run server in background
        pid = fork do
          # In child process - run the server

          # Detach from terminal
          Process.setsid

          # Redirect output to /dev/null
          $stdout.reopen('/dev/null', 'w')
          $stderr.reopen('/dev/null', 'w')

          # Write PID file for server detection
          write_pid_file(cli.port)

          # Clean up PID file on exit
          at_exit do
            delete_pid_file
          end

          # Start server
          set :port, cli.port
          run!
        end

        # In parent process - detach child and exit
        Process.detach(pid)

        # Give server a moment to start
        sleep 1

        puts "Server started in background (PID: #{pid})"
      end

      def find_markdown_files(root_path = @root_path)
        pattern = File.join(root_path, '**', '*.{md,markdown}')
        begin
          Dir.glob(pattern, File::FNM_CASEFOLD).map do |full_path|
            Pathname.new(full_path).relative_path_from(Pathname.new(root_path)).to_s
          end.sort
        rescue Errno::EPERM, Errno::EACCES => e
          # Permission denied on some subdirectory - fall back to non-recursive scan
          warn "Warning: Permission denied scanning #{root_path}, using non-recursive scan"
          find_markdown_files_safe(root_path)
        end
      end

      def find_markdown_files_safe(root_path)
        # Non-recursive scan that skips protected directories
        files = []
        dirs_to_scan = [root_path]

        while dirs_to_scan.any?
          dir = dirs_to_scan.shift
          begin
            Dir.entries(dir).each do |entry|
              next if entry.start_with?('.')
              full_path = File.join(dir, entry)
              if File.directory?(full_path)
                # Skip known protected directories
                next if full_path.include?('/Library/')
                dirs_to_scan << full_path
              elsif entry.match?(/\.(md|markdown)$/i)
                files << Pathname.new(full_path).relative_path_from(Pathname.new(root_path)).to_s
              end
            end
          rescue Errno::EPERM, Errno::EACCES
            # Skip directories we can't access
            next
          end
        end
        files.sort
      end

      def group_files_by_directory(files)
        grouped = {}
        files.each do |file|
          dir = File.dirname(file)
          dir = "." if dir == "."
          grouped[dir] ||= []
          grouped[dir] << File.basename(file)
        end
        # Sort directories, with "." (root) first
        sorted_dirs = grouped.keys.sort do |a, b|
          if a == "."
            -1
          elsif b == "."
            1
          else
            a <=> b
          end
        end
        sorted_dirs.map { |dir| [dir, grouped[dir].sort] }.to_h
      end

      def render_markdown(file_path, root_path = @root_path)
        full_path = File.join(root_path, file_path)
        return nil unless File.exist?(full_path) && File.file?(full_path)

        content = File.read(full_path, encoding: 'UTF-8')
        html = Kramdown::Document.new(content, input: 'GFM', syntax_highlighter: 'rouge').to_html

        # Convert mermaid code blocks to divs for mermaid.js rendering
        html = html.gsub(/<pre><code class="language-mermaid">(.*?)<\/code><\/pre>/m) do
          "<div class=\"mermaid\">#{$1}</div>"
        end

        # Rewrite relative markdown links to use query parameters
        html = rewrite_markdown_links(html, file_path, root_path)

        html
      rescue => e
        "<p>Error rendering markdown: #{e.message}</p>"
      end

      def rewrite_markdown_links(html, current_file, root_path)
        # Get the directory of the current file for resolving relative paths
        current_dir = File.dirname(current_file)
        current_dir = "." if current_dir == "."

        # Rewrite relative links to .md or .markdown files
        html.gsub(/<a\s+href=["']([^"']+)["']([^>]*)>/i) do
          full_match = $&
          href = $1
          rest_of_tag = $2

          # Skip if it's an absolute URL (http://, https://, //, ftp://, mailto:, etc.)
          if href =~ %r{^([a-z][a-z0-9+.-]*:|//)}i
            next full_match
          end

          # Skip if it's an anchor link
          if href.start_with?('#')
            next full_match
          end

          # Only rewrite links to markdown files
          if href =~ /\.(md|markdown)$/i
            # Resolve the relative path from the current file's directory
            if current_dir == "."
              target_file = href
            else
              target_file = File.join(current_dir, href)
            end

            # Normalize the path (remove ./ and resolve ../)
            target_file = Pathname.new(target_file).cleanpath.to_s

            # Rewrite to use query parameters
            encoded_file = CGI.escape(target_file)
            encoded_dir = CGI.escape(root_path)
            %Q{<a href="/?file=#{encoded_file}&dir=#{encoded_dir}"#{rest_of_tag}>}
          else
            # Not a markdown file, leave as-is
            full_match
          end
        end
      end

      def within_root?(real_path, real_root_path = @real_root_path)
        return false unless real_path && real_root_path
        real_path == real_root_path || real_path.start_with?(File.join(real_root_path, ''))
      end

      # Bookmark management methods
      def bookmarks_file
        File.expand_path('~/.markymark/bookmarks.json')
      end

      def load_bookmarks
        return [] unless File.exist?(bookmarks_file)
        JSON.parse(File.read(bookmarks_file))
      rescue JSON::ParserError, Errno::ENOENT
        []
      end

      def save_bookmarks(bookmarks)
        FileUtils.mkdir_p(File.dirname(bookmarks_file))
        File.write(bookmarks_file, JSON.pretty_generate(bookmarks))
      end

      def add_bookmark(name, path)
        bookmarks = load_bookmarks
        # Avoid duplicates
        return if bookmarks.any? { |b| b['path'] == path }
        bookmarks << { 'name' => name, 'path' => path }
        save_bookmarks(bookmarks)
      end

      def remove_bookmark(index)
        bookmarks = load_bookmarks
        bookmarks.delete_at(index.to_i)
        save_bookmarks(bookmarks)
      end

      # PID file management for server detection
      def pid_file_path
        File.expand_path('~/.markymark/server.pid')
      end

      def write_pid_file(port)
        FileUtils.mkdir_p(File.dirname(pid_file_path))
        File.write(pid_file_path, "port=#{port}\npid=#{Process.pid}\n")
      end

      def delete_pid_file
        File.delete(pid_file_path) if File.exist?(pid_file_path)
      end
    end

    # Helper methods for per-tab directory isolation via URL parameters
    helpers do
      def get_directory_from_params
        # Get directory from URL parameter, fall back to server default
        dir_param = params[:dir]

        if dir_param && !dir_param.empty?
          expanded = File.expand_path(dir_param)
          # Validate it exists and is a directory
          if File.exist?(expanded) && File.directory?(expanded)
            return File.realpath(expanded)
          end
        end

        # Fall back to server default
        self.class.root_path
      end
    end

    # Main page - shows file list and optional file content
    get '/' do
      current_dir = get_directory_from_params
      @current_dir = current_dir  # Make available to template for preserving in links
      @files = self.class.find_markdown_files(current_dir)
      @files_grouped = self.class.group_files_by_directory(@files)
      @bookmarks = self.class.load_bookmarks
      @current_file = params[:file]

      if @current_file
        # Security: ensure the requested file path (not symlink target) is within root
        # This allows symlinks that point outside the root, which is useful for
        # linking to shared documentation directories
        full_path = File.join(current_dir, @current_file)

        # Check the file exists and prevent directory traversal
        unless File.exist?(full_path) && (File.file?(full_path) || File.symlink?(full_path))
          halt 404, 'File not found'
        end

        # Prevent path traversal attacks by ensuring the normalized path is within root
        normalized_path = File.expand_path(full_path)
        unless normalized_path.start_with?(File.expand_path(current_dir) + File::SEPARATOR) ||
               normalized_path == File.expand_path(current_dir)
          halt 403, 'Access denied'
        end

        @html_content = self.class.render_markdown(@current_file, current_dir)
      else
        # Default to first file if available
        @current_file = @files.first
        @html_content = @current_file ? self.class.render_markdown(@current_file, current_dir) : nil
      end

      erb :simple
    end

    # Server identification for CLI detection
    get '/api/status' do
      content_type :json
      {
        app: 'markymark',
        version: Markymark::VERSION,
        port: settings.port,
        root_path: get_directory_from_params
      }.to_json
    end

    # Browse directories via web UI
    get '/browse-dir' do
      current_dir = get_directory_from_params
      @browse_path = params[:path] || current_dir
      @current_dir = current_dir  # Pass to template for preserving in form actions

      # Expand and validate the path
      begin
        @browse_path = File.expand_path(@browse_path)

        unless File.exist?(@browse_path)
          @browse_path = current_dir
        end

        unless File.directory?(@browse_path)
          @browse_path = File.dirname(@browse_path)
        end

        # Get parent directory
        @parent_dir = File.dirname(@browse_path)

        # Get subdirectories
        @directories = Dir.entries(@browse_path)
          .select { |entry| entry != '.' && entry != '..' }
          .select { |entry| File.directory?(File.join(@browse_path, entry)) }
          .sort
      rescue => e
        @browse_path = current_dir
        @parent_dir = File.dirname(@browse_path)
        @directories = []
        @error = "Error browsing directory: #{e.message}"
      end

      erb :browse
    end

    # Helper method for dual-format error responses
    def json_or_text_error(message, status)
      if request.accept?('application/json') || request.env['HTTP_ACCEPT']&.include?('application/json')
        content_type :json
        halt status, { error: message }.to_json
      else
        halt status, message
      end
    end

    # Change directory endpoint
    post '/change-dir' do
      new_path = params[:path]&.strip

      unless new_path && !new_path.empty?
        json_or_text_error('Path cannot be empty', 400)
      end

      expanded_path = File.expand_path(new_path)

      unless File.exist?(expanded_path)
        json_or_text_error("Directory does not exist: #{new_path}", 400)
      end

      unless File.directory?(expanded_path)
        json_or_text_error("Path is not a directory: #{new_path}", 400)
      end

      real_path = File.realpath(expanded_path)

      # Update server default for CLI directory switching
      self.class.root_path = real_path
      self.class.real_root_path = real_path

      # Redirect to root with dir parameter for tab isolation
      redirect "/?dir=#{CGI.escape(real_path)}"
    end

    # Add bookmark
    post '/bookmark' do
      name = params[:name]&.strip
      path = params[:path]&.strip

      unless name && !name.empty? && path && !path.empty?
        halt 400, 'Name and path are required'
      end

      expanded_path = File.expand_path(path)

      unless File.exist?(expanded_path) && File.directory?(expanded_path)
        halt 400, 'Invalid directory path'
      end

      self.class.add_bookmark(name, File.realpath(expanded_path))
      redirect '/'
    end

    # Remove bookmark
    delete '/bookmark/:index' do
      index = params[:index]
      self.class.remove_bookmark(index)
      redirect '/'
    end

    # Static file serving from application assets or document root (for images, etc.)
    get '/assets/*' do
      file_path = params[:splat].first

      # First, check application assets (e.g., markymark icon)
      app_assets_path = File.join(File.dirname(__FILE__), '..', '..', 'assets', file_path)
      if File.exist?(app_assets_path) && File.file?(app_assets_path)
        send_file app_assets_path
      else
        # Then check document root assets (user's images)
        current_dir = get_directory_from_params
        full_path = File.join(current_dir, 'assets', file_path)

        # Security: ensure path is within root
        real_path = File.realpath(full_path) rescue nil
        real_current_dir = File.realpath(current_dir)

        if real_path.nil? || !self.class.within_root?(real_path, real_current_dir)
          halt 403, 'Access denied'
        end

        if File.exist?(full_path) && File.file?(full_path)
          send_file full_path
        else
          halt 404, 'File not found'
        end
      end
    end
  end
end
