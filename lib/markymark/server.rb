# frozen_string_literal: true

require 'sinatra/base'
require 'sinatra/streaming'
require 'json'
require 'kramdown'
require 'launchy'
require 'pathname'

module Markymark
  # Sinatra web server for markdown browsing
  class Server < Sinatra::Base
    helpers Sinatra::Streaming

    set :public_folder, File.join(File.dirname(__FILE__), '..', 'public')
    set :views, File.join(File.dirname(__FILE__), '..', 'views')
    set :server, :puma
    set :bind, '0.0.0.0'

    class << self
      attr_accessor :root_path, :file_tree, :watcher, :connections

      def launch(cli)
        @root_path = cli.root_path
        @file_tree = FileTree.new(@root_path)
        @connections = []

        # Start file watcher
        @watcher = Watcher.new(@root_path, self)
        @watcher.start

        # Print startup message
        url = "http://localhost:#{cli.port}"
        puts "markymark serving #{@root_path} on #{url}"

        # Open browser if requested
        Launchy.open(url) if cli.open_browser

        # Start server
        set :port, cli.port
        run!
      end

      def broadcast_file_changed(file_path)
        content = read_file_content(file_path)
        data = { path: file_path, content: content }
        broadcast_event('file_changed', data)
      end

      def broadcast_tree_updated
        # Rebuild file tree
        @file_tree = FileTree.new(@root_path)
        data = @file_tree.build_tree
        broadcast_event('tree_updated', data)
      end

      def broadcast_event(event_type, data)
        json_data = data.to_json
        @connections.each do |connection|
          connection << "event: #{event_type}\n"
          connection << "data: #{json_data}\n\n"
        end
      rescue => e
        warn "Error broadcasting event: #{e.message}"
      end

      def read_file_content(file_path)
        full_path = File.join(@root_path, file_path)
        return nil unless File.exist?(full_path) && File.file?(full_path)

        File.read(full_path)
      end
    end

    # Main page
    get '/' do
      erb :index
    end

    # View specific file
    get '/view' do
      file_path = params[:file]
      halt 400, 'Missing file parameter' unless file_path

      erb :index
    end

    # API: Get file tree
    get '/api/tree' do
      content_type :json
      self.class.file_tree.build_tree.to_json
    end

    # API: Get file content
    get '/api/content' do
      content_type :json
      file_path = params[:file]
      halt 400, { error: 'Missing file parameter' }.to_json unless file_path

      # Security: ensure path is within root
      full_path = File.join(self.class.root_path, file_path)
      real_path = File.realpath(full_path) rescue nil

      if real_path.nil? || !real_path.start_with?(self.class.root_path)
        halt 403, { error: 'Access denied' }.to_json
      end

      unless File.exist?(full_path) && File.file?(full_path)
        halt 404, { error: 'File not found' }.to_json
      end

      content = File.read(full_path)
      { path: file_path, content: content }.to_json
    end

    # API: Get default file
    get '/api/default-file' do
      content_type :json
      default_file = self.class.file_tree.default_file
      { file: default_file }.to_json
    end

    # SSE endpoint for real-time updates
    get '/stream', provides: 'text/event-stream' do
      stream(:keep_open) do |connection|
        # Add connection to list
        self.class.connections << connection

        # Send initial heartbeat
        connection << ": heartbeat\n\n"

        # Keep connection alive with periodic heartbeats
        timer = Thread.new do
          loop do
            sleep 30
            connection << ": heartbeat\n\n"
          rescue
            break
          end
        end

        # Clean up on connection close
        connection.callback do
          timer.kill
          self.class.connections.delete(connection)
        end

        connection.errback do
          timer.kill
          self.class.connections.delete(connection)
        end
      end
    end

    # Static file serving from document root (for images, etc.)
    get '/*' do
      file_path = params[:splat].first
      full_path = File.join(self.class.root_path, file_path)

      # Security: ensure path is within root
      real_path = File.realpath(full_path) rescue nil

      if real_path.nil? || !real_path.start_with?(self.class.root_path)
        halt 403, 'Access denied'
      end

      if File.exist?(full_path) && File.file?(full_path)
        send_file full_path
      else
        halt 404, 'File not found'
      end
    end

    # Graceful shutdown
    at_exit do
      self.watcher&.stop
    end
  end
end
