# frozen_string_literal: true

module Markymark
  # Interactive setup wizard for Markymark
  class InitWizard
    def initialize(accept_defaults: false)
      @accept_defaults = accept_defaults
    end

    def run
      puts "Markymark Setup Wizard"
      puts "=" * 40
      puts ""

      results = {
        app_installed: false,
        default_set: false,
        server_mode: nil
      }

      # Step 1: Install macOS app (macOS only)
      if macos?
        results[:app_installed] = step_install_app

        # Step 2: Set as default handler (only if app was installed)
        if results[:app_installed]
          results[:default_set] = step_set_default
        end
      else
        puts "Skipping macOS app installation (not on macOS)"
        puts ""
      end

      # Step 3: Server mode setup
      results[:server_mode] = step_server_mode

      # Summary
      print_summary(results)

      results
    end

    private

    def macos?
      RUBY_PLATFORM.include?('darwin')
    end

    def step_install_app
      if AppInstaller.installed?
        status = AppInstaller.status
        if status[:valid]
          puts "Markymark.app is already installed and valid."
          return prompt_yes_no("Reinstall anyway?", default: false)
        else
          puts "Warning: #{status[:message]}"
          reinstall = prompt_yes_no("Reinstall Markymark.app?", default: true)
          if reinstall
            return AppInstaller.install(force: true)
          end
          return false
        end
      end

      install = prompt_yes_no("Install Markymark.app for macOS file handling?", default: true)
      return false unless install

      AppInstaller.install(force: true)
    end

    def step_set_default
      set_default = prompt_yes_no("Set Markymark as default app for .md files?", default: true)
      return false unless set_default

      AppInstaller.set_default_handler
    end

    def step_server_mode
      puts "Server mode setup:"
      puts "  1) Standalone (port 4545) - run 'markymark' to start"
      puts "  2) Pumadev (.test domain) - always available at markymark.test"
      puts "  3) Skip - configure later"
      puts ""

      if @accept_defaults
        puts "Using default: Skip (run 'markymark' or 'markymark --setup-pumadev' later)"
        return :skip
      end

      print "Choice [1/2/3, default: 3]: "
      choice = $stdin.gets&.strip

      case choice
      when '1'
        puts ""
        puts "Standalone mode selected."
        puts "Run 'markymark' or 'markymark <directory>' to start the server."
        :standalone
      when '2'
        puts ""
        setup_pumadev
      else
        puts ""
        puts "Skipped. Run 'markymark' or 'markymark --setup-pumadev' later."
        :skip
      end
    end

    def setup_pumadev
      if PumadevManager.active?
        puts "Pumadev is already configured for Markymark."
        puts "Access at: http://markymark.test"
        return :pumadev
      end

      puts "Setting up pumadev..."
      if PumadevManager.setup
        puts "Pumadev configured successfully!"
        puts "Access at: http://markymark.test"
        :pumadev
      else
        puts "Pumadev setup failed. You can try again with: markymark --setup-pumadev"
        :skip
      end
    end

    def prompt_yes_no(question, default: true)
      if @accept_defaults
        puts "#{question} [Y/n] #{default ? 'Y' : 'n'} (auto)"
        return default
      end

      default_hint = default ? "[Y/n]" : "[y/N]"
      print "#{question} #{default_hint} "
      response = $stdin.gets&.strip&.downcase

      return default if response.nil? || response.empty?

      case response
      when 'y', 'yes'
        true
      when 'n', 'no'
        false
      else
        default
      end
    end

    def print_summary(results)
      puts ""
      puts "=" * 40
      puts "Setup Summary"
      puts "=" * 40

      if macos?
        if results[:app_installed]
          puts "  [x] Markymark.app installed to ~/Applications"
        else
          puts "  [ ] Markymark.app not installed"
        end

        if results[:default_set]
          puts "  [x] Set as default handler for .md files"
        else
          puts "  [ ] Not set as default handler"
        end
      end

      case results[:server_mode]
      when :standalone
        puts "  [x] Standalone mode (run 'markymark' to start)"
      when :pumadev
        puts "  [x] Pumadev mode (http://markymark.test)"
      else
        puts "  [ ] Server mode not configured"
      end

      puts ""
      puts "You can always reconfigure with:"
      puts "  markymark --install-app      # Install/reinstall macOS app"
      puts "  markymark --set-default      # Set as default .md handler"
      puts "  markymark --setup-pumadev    # Setup pumadev integration"
      puts ""
    end
  end
end
