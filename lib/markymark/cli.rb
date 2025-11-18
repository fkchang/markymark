# frozen_string_literal: true

require 'optparse'
require 'net/http'
require 'json'
require 'socket'

module Markymark
  # Command-line interface handler
  class CLI
    DEFAULT_PORT = 4545

    attr_reader :root_path, :port, :open_browser

    def initialize(args)
      @root_path = Dir.pwd
      @port = DEFAULT_PORT
      @open_browser = true

      parse_options(args)
      validate!
    end

    def self.run(args)
      cli = new(args)

      # Check if a markymark server is already running
      existing_server = cli.send(:detect_existing_server)

      if existing_server
        # Server exists - switch it to the new directory
        cli.send(:handle_existing_server, existing_server)
      else
        # No server running - start a new one (check for port conflicts)
        if cli.send(:port_available?, cli.port)
          ServerSimple.launch(cli)
        else
          # Port is busy - prompt user
          cli.send(:handle_port_conflict)
        end
      end
    rescue => e
      warn "Error: #{e.message}"
      warn e.backtrace.join("\n")
      exit 1
    end

    def self.show_pumadev_instructions
      puts <<~INSTRUCTIONS
        Pumadev Setup for markymark
        ============================

        Pumadev allows you to access markymark via a .test domain instead of remembering ports.

        Setup Instructions:

        1. Install pumadev (if not already installed):
           gem install puma-dev

        2. Set up pumadev:
           sudo puma-dev -setup
           puma-dev -install

        3. Find your markymark gem installation:
           gem which markymark

        4. Create a symlink in ~/.puma-dev/:
           cd ~/.puma-dev
           ln -s /path/to/markymark/gem markymark

        5. Access markymark at:
           http://markymark.test

        Notes for Ruby Version Manager Users:
        - Install markymark in your global gemset of your default Ruby
        - This ensures the command is available across all Ruby versions
        - The symlink points to the gem location, which pumadev will use

        Smart Directory Switching:
        - The smart directory switching feature works with pumadev
        - Run 'markymark' from any directory to switch the server
        - The MARKYMARK_ROOT environment variable can be set if needed

        For more information: https://github.com/puma/puma-dev
      INSTRUCTIONS
    end

    private

    def parse_options(args)
      parser = OptionParser.new do |opts|
        opts.banner = <<~BANNER
          markymark - Browse markdown documentation with live reload

          Usage: markymark [PATH] [OPTIONS]

          Arguments:
            PATH                     Directory to browse (default: current directory)

          Options:
        BANNER

        opts.on('-p', '--port PORT', Integer, "Port to run server on (default: #{DEFAULT_PORT})") do |p|
          @port = p
        end

        opts.on('--no-browser', 'Do not auto-open browser on startup') do
          @open_browser = false
        end

        opts.on('-h', '--help', 'Show this help message') do
          puts opts
          exit
        end

        opts.on('-v', '--version', 'Show version') do
          puts "markymark #{Markymark::VERSION}"
          exit
        end

        opts.on('--pumadev', 'Show pumadev setup instructions') do
          show_pumadev_instructions
          exit
        end
      end

      parser.parse!(args)

      # First non-option argument is the path
      @root_path = args.first if args.any?
    end

    def validate!
      expanded_path = File.expand_path(@root_path)

      unless File.exist?(expanded_path)
        raise ArgumentError, "Path does not exist: #{@root_path}"
      end

      unless File.directory?(expanded_path)
        raise ArgumentError, "Path is not a directory: #{@root_path}"
      end

      @root_path = File.realpath(expanded_path)

      unless @port.between?(1, 65535)
        raise ArgumentError, "Port must be between 1 and 65535"
      end
    end

    # Detect if a markymark server is already running
    def detect_existing_server
      pid_file = File.expand_path('~/.markymark/server.pid')
      return nil unless File.exist?(pid_file)

      # Parse PID file
      content = File.read(pid_file)
      port = content[/port=(\d+)/, 1]&.to_i
      pid = content[/pid=(\d+)/, 1]&.to_i

      return nil unless port && pid

      # Check if process is still running
      begin
        Process.kill(0, pid)
      rescue Errno::ESRCH
        # Process not found - clean up stale PID file
        File.delete(pid_file)
        return nil
      end

      # Verify it's actually a markymark server by checking /api/status
      begin
        uri = URI("http://localhost:#{port}/api/status")
        response = Net::HTTP.get_response(uri)
        if response.is_a?(Net::HTTPSuccess)
          data = JSON.parse(response.body)
          return { port: port, pid: pid } if data['app'] == 'markymark'
        end
      rescue => e
        # Server not responding or not markymark - ignore
      end

      nil
    end

    # Handle existing server - switch directory and open browser
    def handle_existing_server(server_info)
      puts "Found existing markymark server on port #{server_info[:port]}"
      puts "Switching to #{@root_path}..."

      if switch_server_directory(server_info[:port], @root_path)
        puts "Successfully switched to #{@root_path}"

        # Open browser if requested
        if @open_browser
          url = "http://localhost:#{server_info[:port]}"
          require 'launchy'
          Launchy.open(url)
        end
      else
        warn "Failed to switch directory. Starting new server instead..."
        # Port might be available now if switch failed
        if port_available?(@port)
          ServerSimple.launch(self)
        else
          handle_port_conflict
        end
      end
    end

    # Handle port conflict with non-markymark app
    def handle_port_conflict
      puts "Port #{@port} is already in use by another application."
      puts "What would you like to do?"
      puts "  1) Start markymark on a different port"
      puts "  2) Cancel"
      print "Choice (1-2): "

      choice = $stdin.gets&.strip

      case choice
      when "1"
        new_port = find_available_port(@port + 1)
        if new_port
          puts "Starting markymark on port #{new_port}..."
          @port = new_port
          ServerSimple.launch(self)
        else
          warn "Could not find an available port"
          exit 1
        end
      else
        puts "Cancelled"
        exit 0
      end
    end

    # Switch directory on existing server
    def switch_server_directory(port, new_path)
      uri = URI("http://localhost:#{port}/change-dir")
      request = Net::HTTP::Post.new(uri)
      request.set_form_data('path' => new_path)
      request['Accept'] = 'application/json'

      begin
        response = Net::HTTP.start(uri.hostname, uri.port, read_timeout: 5) do |http|
          http.request(request)
        end

        if response.is_a?(Net::HTTPSuccess)
          data = JSON.parse(response.body)
          return data['success']
        else
          warn "Server returned error: #{response.code}"
          return false
        end
      rescue => e
        warn "Failed to communicate with server: #{e.message}"
        return false
      end
    end

    # Check if a port is available
    def port_available?(port)
      TCPServer.open('127.0.0.1', port) do |server|
        server.close
        true
      end
    rescue Errno::EADDRINUSE, Errno::EACCES
      false
    end

    # Find next available port starting from given port
    def find_available_port(start_port)
      (start_port..65535).each do |port|
        return port if port_available?(port)
      end
      nil
    end
  end
end
