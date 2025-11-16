# frozen_string_literal: true

require 'optparse'

module Markymark
  # Command-line interface handler
  class CLI
    DEFAULT_PORT = 4567

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

      ServerSimple.launch(cli)
    rescue => e
      warn "Error: #{e.message}"
      warn e.backtrace.join("\n")
      exit 1
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
  end
end
