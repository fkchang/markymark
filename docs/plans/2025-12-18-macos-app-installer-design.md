# macOS App Installer & Init Wizard Design

**Date:** 2025-12-18
**Status:** Approved

## Overview

Add the ability to install Markymark as a macOS application that can be registered as the default handler for `.md` files. Includes an interactive setup wizard and standalone CLI flags.

## CLI Interface

### New Commands

```bash
markymark init              # Interactive setup wizard
markymark init -y           # Accept all defaults (scripted)
markymark --install-app     # Install macOS app bundle only
markymark --set-default     # Set as default .md handler only
markymark --uninstall-app   # Remove the app bundle
```

### Init Wizard Flow

1. "Install Markymark.app for macOS file handling? [Y/n]"
2. "Set Markymark as default app for .md files? [Y/n]" (only if step 1 was yes)
3. "Setup server mode?" → choices: standalone (port 4545) / pumadev / skip
4. Summary of what was configured

**Defaults for `-y` flag:** Install app, set as default, skip server setup.

## macOS App Bundle

### Location

`~/Applications/Markymark.app` - User's Applications folder, no sudo needed, persists across gem updates.

### Structure

```
Markymark.app/
├── Contents/
│   ├── Info.plist          # App metadata, file associations
│   ├── MacOS/
│   │   └── markymark-launcher  # Shell script with baked-in Ruby paths
│   └── Resources/
│       └── Markymark.icns  # App icon
```

### Info.plist Key Elements

- `CFBundleDocumentTypes` - Registers for `.md`, `.markdown` files
- `CFBundleIdentifier` - `com.markymark.app`
- `CFBundleURLTypes` - Optional URL scheme `markymark://`

### Launcher Script Strategy

At install time, capture the current Ruby environment and bake it into the launcher:

```bash
# During install, detect:
RUBY_PATH=$(which ruby)
MARKYMARK_PATH=$(which markymark)

# Generated launcher uses exact paths:
#!/bin/bash
exec /path/to/ruby /path/to/markymark "$@"
```

**Benefits:**
- No runtime version manager detection needed
- Works with any Ruby setup (rvm, rbenv, asdf, homebrew, system)
- Guaranteed to use the same Ruby that installed the gem

**Caveat:** If user changes Ruby versions, they need to run `markymark --install-app` again.

## Implementation Structure

### New Files

**`lib/markymark/app_installer.rb`**

Handles:
- Creating the `.app` bundle structure
- Generating `Info.plist` with file associations
- Writing the launcher script with baked-in Ruby paths
- Copying the icon from gem assets
- Setting executable permissions
- Registering as default handler (via `duti` or `lsregister`)

**`lib/markymark/init_wizard.rb`**

Handles:
- Interactive prompts
- `-y` flag for accepting defaults
- Calling `AppInstaller` and `PumadevManager` as needed

### CLI Additions (`lib/markymark/cli.rb`)

```ruby
opts.on('--install-app', 'Install macOS app bundle to ~/Applications')
opts.on('--uninstall-app', 'Remove macOS app bundle')
opts.on('--set-default', 'Set as default handler for .md files')
# init handled as subcommand
```

## Error Handling

### Pre-flight Checks for `--install-app`

- macOS only (fail gracefully on Linux/Windows with helpful message)
- Check `~/Applications` exists (create if not)
- Warn if app already exists, ask to overwrite

### Pre-flight Checks for `--set-default`

- App must be installed first
- Check if `duti` is available; if not, fall back to manual instructions

### Launcher Script Errors

- If baked-in Ruby path no longer exists → show error dialog via `osascript`
- Pass through markymark errors to Console.app for debugging

### Version Mismatch Detection

On `markymark --status`:
- Check if installed app's Ruby path still exists
- Warn: "Markymark.app may need reinstalling (Ruby path changed)"

## Web UI & README Updates

### Sidebar Header (simple.erb)

- Add `marky-mark-icon2.png` as small logo (~48px)
- Position above or beside "Markymark" title

### README.md

- Add DJ image (`marky-mark-dj.jpg`) at top as project banner
- Add "Installation" section covering `markymark init`
- Document all new flags

## Assets

Already prepared:
- `assets/marky-mark-icon2.png` - 1024x1024 source icon
- `assets/Markymark.icns` - macOS app icon bundle
- `assets/Markymark.iconset/` - All icon sizes (16-1024)
- `assets/marky-mark-dj.jpg` - README banner image
