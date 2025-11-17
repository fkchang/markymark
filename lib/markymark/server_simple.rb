# frozen_string_literal: true

require 'sinatra/base'
require 'json'
require 'kramdown'
require 'launchy'
require 'pathname'

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
        url = "http://localhost:#{cli.port}"
        puts "markymark serving #{@root_path} on #{url}"
        puts "Press Ctrl+C to stop"

        # Open browser if requested
        Launchy.open(url) if cli.open_browser

        # Start server
        set :port, cli.port
        run!
      end

      def find_markdown_files
        pattern = File.join(@root_path, '**', '*.{md,markdown}')
        Dir.glob(pattern, File::FNM_CASEFOLD).map do |full_path|
          Pathname.new(full_path).relative_path_from(Pathname.new(@root_path)).to_s
        end.sort
      end

      def render_markdown(file_path)
        full_path = File.join(@root_path, file_path)
        return nil unless File.exist?(full_path) && File.file?(full_path)

        content = File.read(full_path)
        html = Kramdown::Document.new(content, input: 'GFM', syntax_highlighter: 'rouge').to_html

        # Convert mermaid code blocks to divs for mermaid.js rendering
        html.gsub(/<pre><code class="language-mermaid">(.*?)<\/code><\/pre>/m) do
          "<div class=\"mermaid\">#{$1}</div>"
        end
      rescue => e
        "<p>Error rendering markdown: #{e.message}</p>"
      end

      def within_root?(real_path)
        return false unless real_path && @real_root_path
        real_path == @real_root_path || real_path.start_with?(File.join(@real_root_path, ''))
      end
    end

    # Main page - shows file list and optional file content
    get '/' do
      @files = self.class.find_markdown_files
      @current_file = params[:file]

      if @current_file
        # Security: ensure path is within root
        full_path = File.join(self.class.root_path, @current_file)
        real_path = File.realpath(full_path) rescue nil

        if real_path.nil? || !self.class.within_root?(real_path)
          halt 403, 'Access denied'
        end

        @html_content = self.class.render_markdown(@current_file)
      else
        # Default to first file if available
        @current_file = @files.first
        @html_content = @current_file ? self.class.render_markdown(@current_file) : nil
      end

      erb :simple
    end

    # Browse directories via web UI
    get '/browse-dir' do
      @browse_path = params[:path] || self.class.root_path

      # Expand and validate the path
      begin
        @browse_path = File.expand_path(@browse_path)

        unless File.exist?(@browse_path)
          @browse_path = self.class.root_path
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
        @browse_path = self.class.root_path
        @parent_dir = File.dirname(@browse_path)
        @directories = []
        @error = "Error browsing directory: #{e.message}"
      end

      erb :browse
    end

    # Change directory endpoint
    post '/change-dir' do
      new_path = params[:path]&.strip

      unless new_path && !new_path.empty?
        halt 400, 'Path cannot be empty'
      end

      expanded_path = File.expand_path(new_path)

      unless File.exist?(expanded_path)
        halt 400, "Directory does not exist: #{new_path}"
      end

      unless File.directory?(expanded_path)
        halt 400, "Path is not a directory: #{new_path}"
      end

      # Update the root path
      self.class.root_path = File.realpath(expanded_path)
      self.class.real_root_path = File.realpath(expanded_path)

      redirect '/'
    end

    # Static file serving from document root (for images, etc.)
    get '/assets/*' do
      file_path = params[:splat].first
      full_path = File.join(self.class.root_path, file_path)

      # Security: ensure path is within root
      real_path = File.realpath(full_path) rescue nil

      if real_path.nil? || !self.class.within_root?(real_path)
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
