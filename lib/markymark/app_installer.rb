# frozen_string_literal: true

require 'fileutils'
require 'json'

module Markymark
  # Installs Markymark as a macOS application for file handling
  class AppInstaller
    APP_NAME = 'Markymark.app'
    BUNDLE_ID = 'com.markymark.app'
    APP_DIR = File.expand_path('~/Applications')
    APP_PATH = File.join(APP_DIR, APP_NAME)

    class << self
      def install(force: false)
        unless macos?
          warn "App installation is only supported on macOS"
          return false
        end

        if File.exist?(APP_PATH) && !force
          print "Markymark.app already exists. Overwrite? [y/N] "
          response = $stdin.gets&.strip&.downcase
          return false unless response == 'y'
        end

        puts "Installing Markymark.app to ~/Applications..."

        begin
          create_app_bundle
          puts "Successfully installed Markymark.app"
          puts "Location: #{APP_PATH}"
          true
        rescue => e
          warn "Failed to install app: #{e.message}"
          false
        end
      end

      def uninstall
        unless macos?
          warn "App uninstallation is only supported on macOS"
          return false
        end

        unless File.exist?(APP_PATH)
          puts "Markymark.app is not installed"
          return true
        end

        puts "Removing Markymark.app..."
        FileUtils.rm_rf(APP_PATH)
        puts "Successfully removed Markymark.app"
        true
      rescue => e
        warn "Failed to uninstall app: #{e.message}"
        false
      end

      def set_default_handler
        unless macos?
          warn "Setting default handler is only supported on macOS"
          return false
        end

        unless File.exist?(APP_PATH)
          warn "Markymark.app must be installed first. Run: markymark --install-app"
          return false
        end

        puts "Setting Markymark as default handler for .md files..."

        # Try duti first (more reliable)
        if duti_available?
          return set_default_with_duti
        end

        # duti not installed - offer to install it
        if homebrew_available?
          puts ""
          puts "For automatic default app registration, 'duti' is recommended."
          print "Install duti via Homebrew? [Y/n] "
          response = $stdin.gets&.strip&.downcase

          if response.nil? || response.empty? || response == 'y' || response == 'yes'
            puts "Installing duti..."
            if system('brew install duti')
              puts "duti installed successfully."
              return set_default_with_duti
            else
              warn "Failed to install duti."
            end
          end
        end

        # Fall back to lsregister + manual instructions
        lsregister = '/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
        if File.exist?(lsregister)
          # Register the app
          system("#{lsregister} -f '#{APP_PATH}'")
          puts ""
          puts "Registered Markymark.app with Launch Services."
          puts ""
          puts "To complete setup, please manually set Markymark as default:"
          puts "  1. Right-click any .md file in Finder"
          puts "  2. Select 'Get Info'"
          puts "  3. Under 'Open with:', select 'Markymark'"
          puts "  4. Click 'Change All...'"
          return true
        end

        warn "Could not set default handler automatically."
        puts "Please install 'duti' (brew install duti) or set manually via Finder."
        false
      end

      def set_default_with_duti
        success = system("duti -s #{BUNDLE_ID} .md all") &&
                  system("duti -s #{BUNDLE_ID} .markdown all")
        if success
          puts "Successfully set Markymark as default handler for .md files"
          return true
        end
        false
      end

      def duti_available?
        system('which duti > /dev/null 2>&1')
      end

      def homebrew_available?
        system('which brew > /dev/null 2>&1')
      end

      def installed?
        File.exist?(APP_PATH)
      end

      def status
        return nil unless macos?

        unless File.exist?(APP_PATH)
          return { installed: false, message: "Markymark.app is not installed" }
        end

        launcher_path = File.join(APP_PATH, 'Contents', 'MacOS', 'markymark-launcher')
        unless File.exist?(launcher_path)
          return { installed: true, valid: false, message: "Markymark.app is corrupted (missing launcher)" }
        end

        # Check if the baked-in Ruby path still exists (stored in helper script)
        helper_path = File.join(APP_PATH, 'Contents', 'MacOS', 'markymark-helper')
        unless File.exist?(helper_path)
          return { installed: true, valid: false, message: "Markymark.app is corrupted (missing helper)" }
        end

        helper_content = File.read(helper_path)
        ruby_path = helper_content[/RUBY_PATH="([^"]+)"/, 1]

        if ruby_path && !File.exist?(ruby_path)
          return {
            installed: true,
            valid: false,
            ruby_path: ruby_path,
            message: "Markymark.app needs reinstalling (Ruby path changed: #{ruby_path})"
          }
        end

        {
          installed: true,
          valid: true,
          ruby_path: ruby_path,
          message: "Markymark.app is installed and valid"
        }
      end

      private

      def macos?
        RUBY_PLATFORM.include?('darwin')
      end

      def create_app_bundle
        # Create directory structure
        FileUtils.mkdir_p(APP_DIR)
        FileUtils.rm_rf(APP_PATH) if File.exist?(APP_PATH)

        contents_dir = File.join(APP_PATH, 'Contents')
        macos_dir = File.join(contents_dir, 'MacOS')
        resources_dir = File.join(contents_dir, 'Resources')

        FileUtils.mkdir_p(macos_dir)
        FileUtils.mkdir_p(resources_dir)

        # Write Info.plist
        write_info_plist(contents_dir)

        # Write launcher script
        write_launcher_script(macos_dir)

        # Copy icon
        copy_icon(resources_dir)
      end

      def write_info_plist(contents_dir)
        plist_path = File.join(contents_dir, 'Info.plist')

        plist_content = <<~PLIST
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
          <plist version="1.0">
          <dict>
            <key>CFBundleName</key>
            <string>Markymark</string>
            <key>CFBundleDisplayName</key>
            <string>Markymark</string>
            <key>CFBundleIdentifier</key>
            <string>#{BUNDLE_ID}</string>
            <key>CFBundleVersion</key>
            <string>#{Markymark::VERSION}</string>
            <key>CFBundleShortVersionString</key>
            <string>#{Markymark::VERSION}</string>
            <key>CFBundlePackageType</key>
            <string>APPL</string>
            <key>CFBundleExecutable</key>
            <string>markymark-launcher</string>
            <key>CFBundleIconFile</key>
            <string>Markymark</string>
            <key>LSMinimumSystemVersion</key>
            <string>10.13</string>
            <key>NSHighResolutionCapable</key>
            <true/>
            <key>CFBundleDocumentTypes</key>
            <array>
              <dict>
                <key>CFBundleTypeName</key>
                <string>Markdown Document</string>
                <key>CFBundleTypeRole</key>
                <string>Viewer</string>
                <key>LSHandlerRank</key>
                <string>Default</string>
                <key>LSItemContentTypes</key>
                <array>
                  <string>net.daringfireball.markdown</string>
                  <string>public.text</string>
                </array>
                <key>CFBundleTypeExtensions</key>
                <array>
                  <string>md</string>
                  <string>markdown</string>
                  <string>mdown</string>
                  <string>mkd</string>
                </array>
              </dict>
            </array>
            <key>UTImportedTypeDeclarations</key>
            <array>
              <dict>
                <key>UTTypeIdentifier</key>
                <string>net.daringfireball.markdown</string>
                <key>UTTypeDescription</key>
                <string>Markdown Document</string>
                <key>UTTypeConformsTo</key>
                <array>
                  <string>public.plain-text</string>
                </array>
                <key>UTTypeTagSpecification</key>
                <dict>
                  <key>public.filename-extension</key>
                  <array>
                    <string>md</string>
                    <string>markdown</string>
                    <string>mdown</string>
                    <string>mkd</string>
                  </array>
                </dict>
              </dict>
            </array>
          </dict>
          </plist>
        PLIST

        File.write(plist_path, plist_content)
      end

      def write_launcher_script(macos_dir)
        ruby_path = which_ruby
        markymark_path = which_markymark

        # Write the shell script helper
        gem_home = ENV['GEM_HOME'] || Gem.dir
        gem_path = ENV['GEM_PATH'] || Gem.path.join(':')
        markymark_lib = File.dirname(File.dirname(markymark_path))

        helper_path = File.join(macos_dir, 'markymark-helper')
        helper_content = <<~SCRIPT
          #!/bin/bash
          # Markymark helper - called by the Swift launcher

          RUBY_PATH="#{ruby_path}"
          MARKYMARK_PATH="#{markymark_path}"
          GEM_HOME="#{gem_home}"
          GEM_PATH="#{gem_path}"
          MARKYMARK_LIB="#{markymark_lib}/lib"
          LOG_FILE="$HOME/.markymark/launcher.log"
          mkdir -p "$(dirname "$LOG_FILE")"
          echo "$(date): Helper called with: $@" >> "$LOG_FILE"

          # Check if Ruby still exists
          if [ ! -f "$RUBY_PATH" ]; then
            osascript -e 'display alert "Markymark Error" message "Ruby installation has changed. Please run: markymark --install-app" as critical'
            exit 1
          fi

          # Check if markymark still exists
          if [ ! -f "$MARKYMARK_PATH" ]; then
            osascript -e 'display alert "Markymark Error" message "Markymark gem not found. Please run: gem install markymark && markymark --install-app" as critical'
            exit 1
          fi

          # Set up gem environment and launch markymark
          export GEM_HOME="$GEM_HOME"
          export GEM_PATH="$GEM_PATH"
          export RUBYLIB="$MARKYMARK_LIB:$RUBYLIB"
          "$RUBY_PATH" "$MARKYMARK_PATH" "$@" >> "$LOG_FILE" 2>&1 &
        SCRIPT
        File.write(helper_path, helper_content)
        FileUtils.chmod(0o755, helper_path)

        # Compile a Swift binary that properly receives files from Launch Services
        # AppleScript droplets don't work with macOS `open` command (used by iTerm cmd-click)
        write_swift_launcher(macos_dir, helper_path)
      end

      def write_swift_launcher(macos_dir, helper_path)
        # Check if Swift compiler is available
        unless system('which swiftc > /dev/null 2>&1')
          raise "Swift compiler not found. Install Xcode Command Line Tools with: xcode-select --install"
        end

        swift_source = <<~SWIFT
          import Cocoa

          class AppDelegate: NSObject, NSApplicationDelegate {
              let helperPath = "#{helper_path}"
              var hasOpenedFile = false

              func applicationDidFinishLaunching(_ notification: Notification) {
                  // Give time for openFile to be called first
                  DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                      if !self.hasOpenedFile {
                          // Launched without files - open home directory
                          self.openFile(path: NSHomeDirectory())
                      }
                      NSApp.terminate(nil)
                  }
              }

              func application(_ sender: NSApplication, openFile filename: String) -> Bool {
                  hasOpenedFile = true
                  openFile(path: filename)
                  return true
              }

              func openFile(path: String) {
                  let task = Process()
                  task.executableURL = URL(fileURLWithPath: helperPath)
                  task.arguments = [path]
                  try? task.run()
              }
          }

          let app = NSApplication.shared
          let delegate = AppDelegate()
          app.delegate = delegate
          app.run()
        SWIFT

        # Write Swift source to temp file
        temp_swift = File.join(Dir.tmpdir, 'markymark_launcher.swift')
        File.write(temp_swift, swift_source)

        # Compile Swift binary
        launcher_path = File.join(macos_dir, 'markymark-launcher')
        success = system("swiftc -o '#{launcher_path}' '#{temp_swift}' -framework Cocoa 2>&1")

        unless success
          File.delete(temp_swift) if File.exist?(temp_swift)
          raise "Failed to compile Swift launcher"
        end

        FileUtils.chmod(0o755, launcher_path)
        File.delete(temp_swift) if File.exist?(temp_swift)
      end

      def copy_icon(resources_dir)
        # Find the icon in the gem's assets
        gem_root = File.expand_path('../../..', __FILE__)
        icon_source = File.join(gem_root, 'assets', 'Markymark.icns')

        unless File.exist?(icon_source)
          warn "Warning: Icon file not found at #{icon_source}"
          return
        end

        icon_dest = File.join(resources_dir, 'Markymark.icns')
        FileUtils.cp(icon_source, icon_dest)
      end

      def which_ruby
        # Get the full path to the current Ruby
        RbConfig.ruby
      end

      def which_markymark
        # Find the actual executable inside the gem, not the wrapper script
        # RVM/rbenv wrappers don't work when launched from outside their environment
        begin
          spec = Gem::Specification.find_by_name('markymark')
          exe_path = File.join(spec.gem_dir, 'exe', 'markymark')
          return exe_path if File.exist?(exe_path)
        rescue Gem::MissingSpecError
          # Gem not found via spec
        end

        # Fallback: try to find via gem contents
        contents = `gem contents markymark 2>/dev/null`.strip
        contents.each_line do |line|
          return line.strip if line.include?('/exe/markymark')
        end

        # Last resort fallback
        '/usr/local/bin/markymark'
      end
    end
  end
end
