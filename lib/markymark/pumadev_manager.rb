# frozen_string_literal: true

require 'fileutils'

module Markymark
  # Manages pumadev integration for markymark
  class PumadevManager
    class << self
      def symlink_path
        File.expand_path('~/.puma-dev/markymark')
      end

      def env_file_path
        File.expand_path('~/.markymark/.pumadev_root')
      end

      def marker_file_path
        File.expand_path('~/.markymark/.pumadev_mode')
      end

      # Check if pumadev mode is currently active
      def active?
        File.exist?(marker_file_path) && File.symlink?(symlink_path)
      end

      # Check if puma-dev is installed
      def puma_dev_installed?
        `which puma-dev`.strip != ''
      end

      # Get the gem installation directory
      def gem_directory
        gem_spec = Gem::Specification.find_by_name('markymark')
        gem_spec.gem_dir
      rescue Gem::LoadError
        # If gem not found, we're in development mode
        File.expand_path(File.join(__dir__, '..', '..'))
      end

      # Setup pumadev integration
      def setup(path = nil)
        ensure_puma_dev_installed!

        gem_dir = gem_directory
        puma_dev_dir = File.dirname(symlink_path)

        # Create ~/.puma-dev if it doesn't exist
        FileUtils.mkdir_p(puma_dev_dir) unless File.exist?(puma_dev_dir)

        # Create symlink to gem directory
        if File.symlink?(symlink_path)
          existing_target = File.readlink(symlink_path)
          if existing_target == gem_dir
            puts "Pumadev symlink already exists and points to correct location"
          else
            puts "Updating pumadev symlink from #{existing_target} to #{gem_dir}"
            File.delete(symlink_path)
            File.symlink(gem_dir, symlink_path)
          end
        elsif File.exist?(symlink_path)
          raise "#{symlink_path} exists but is not a symlink. Please remove it manually."
        else
          puts "Creating pumadev symlink: #{symlink_path} -> #{gem_dir}"
          File.symlink(gem_dir, symlink_path)
        end

        # Store the root path if provided
        if path
          expanded_path = File.expand_path(path)
          unless File.directory?(expanded_path)
            raise ArgumentError, "Path is not a directory: #{path}"
          end
          save_root_path(expanded_path)
          puts "Set markymark root directory to: #{expanded_path}"
        else
          save_root_path(Dir.pwd)
          puts "Set markymark root directory to: #{Dir.pwd}"
        end

        # Create marker file
        FileUtils.mkdir_p(File.dirname(marker_file_path))
        File.write(marker_file_path, Time.now.to_s)

        puts "\nPumadev setup complete!"
        puts "Access markymark at: http://markymark.test"
        puts "\nNote: It may take a few seconds for pumadev to start the app on first access."

        true
      rescue => e
        warn "Failed to setup pumadev: #{e.message}"
        false
      end

      # Teardown pumadev integration
      def teardown
        removed_anything = false

        # Remove symlink
        if File.symlink?(symlink_path)
          File.delete(symlink_path)
          puts "Removed pumadev symlink"
          removed_anything = true
        end

        # Remove root path file
        if File.exist?(env_file_path)
          File.delete(env_file_path)
          removed_anything = true
        end

        # Remove marker file
        if File.exist?(marker_file_path)
          File.delete(marker_file_path)
          removed_anything = true
        end

        if removed_anything
          puts "Pumadev integration removed"
          puts "The app will stop automatically when pumadev next restarts"
        else
          puts "Pumadev integration was not active"
        end

        true
      rescue => e
        warn "Error during pumadev teardown: #{e.message}"
        false
      end

      # Get current status
      def status
        if active?
          root_path = load_root_path
          {
            mode: :pumadev,
            url: 'http://markymark.test',
            root_path: root_path,
            message: "Running via pumadev at http://markymark.test\nServing: #{root_path}"
          }
        else
          nil
        end
      end

      # Switch directory in pumadev mode
      def switch_directory(new_path)
        expanded_path = File.expand_path(new_path)

        unless File.directory?(expanded_path)
          raise ArgumentError, "Path is not a directory: #{new_path}"
        end

        save_root_path(expanded_path)
        puts "Switched to #{expanded_path}"
        puts "Restart required - touch your ~/.puma-dev/markymark symlink or wait for next request"

        # Trigger a restart by touching the restart.txt file
        restart_txt = File.join(gem_directory, 'tmp', 'restart.txt')
        FileUtils.mkdir_p(File.dirname(restart_txt))
        FileUtils.touch(restart_txt)

        true
      rescue => e
        warn "Failed to switch directory: #{e.message}"
        false
      end

      private

      def ensure_puma_dev_installed!
        unless puma_dev_installed?
          raise "puma-dev is not installed. Install it with: gem install puma-dev\n" \
                "Then run: sudo puma-dev -setup && puma-dev -install"
        end
      end

      def save_root_path(path)
        FileUtils.mkdir_p(File.dirname(env_file_path))
        File.write(env_file_path, path)

        # Also set it as an environment variable for the current process
        ENV['MARKYMARK_ROOT'] = path
      end

      def load_root_path
        if File.exist?(env_file_path)
          File.read(env_file_path).strip
        else
          ENV['MARKYMARK_ROOT'] || Dir.pwd
        end
      end
    end
  end
end
