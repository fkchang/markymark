# markymark - LLM Context Guide

This document helps LLMs understand markymark's architecture and how to work with the codebase effectively.

## What is markymark?

markymark is a **dedicated local markdown viewer** that runs on any platform with Ruby. On macOS, it integrates with the operating system like a native app - double-click a `.md` file in Finder, cmd-click in iTerm, or run `open file.md` and it opens beautifully rendered in markymark.

## Quick Reference

### Installation & Setup
```bash
gem install markymark
markymark init        # Interactive setup wizard
markymark init -y     # Accept all defaults
```

### Common Commands
```bash
markymark                    # Browse current directory
markymark README.md          # Open specific file
markymark ~/docs             # Browse specific directory
markymark --status           # Check server status
markymark --stop             # Stop server
markymark --install-app      # Install macOS app
markymark --set-default      # Set as default .md handler
```

## Architecture Overview

### Core Components

| File | Purpose |
|------|---------|
| `lib/markymark/cli.rb` | Command-line interface, argument parsing, server management |
| `lib/markymark/server_simple.rb` | Sinatra-based web server, markdown rendering, file discovery |
| `lib/markymark/app_installer.rb` | macOS app bundle creation, Swift launcher compilation |
| `lib/markymark/init_wizard.rb` | Interactive setup wizard |
| `lib/markymark/pumadev_manager.rb` | puma-dev integration for `.test` domains |

### Key Files

- `exe/markymark` - Entry point executable
- `lib/views/simple.erb` - Main HTML template
- `lib/public/css/style.css` - Styling
- `lib/public/js/theme.js` - Dark/light theme toggle
- `assets/Markymark.icns` - macOS app icon

### How the macOS App Works

The app bundle at `~/Applications/Markymark.app` contains:
1. **Swift launcher** (`Contents/MacOS/markymark-launcher`) - Compiled binary that receives files from Launch Services via `NSApplicationDelegate.application(_:openFile:)`
2. **Shell helper** (`Contents/MacOS/markymark-helper`) - Called by Swift launcher, sets up Ruby environment and invokes markymark CLI
3. **Info.plist** - Declares file type associations (`.md`, `.markdown`, `.mdown`, `.mkd`)

This architecture is necessary because:
- AppleScript droplets don't receive files from macOS `open` command
- Ruby scripts can't be registered as file handlers directly
- Swift properly implements the Launch Services file-opening protocol

### Server Architecture

markymark runs as a **single persistent server**:
- PID tracked in `~/.markymark/server.pid`
- Supports directory switching without restart via `/switch` endpoint
- Can run in standalone mode (port 4545) or pumadev mode (markymark.test)

### Data Storage

All persistent data stored in `~/.markymark/`:
- `server.pid` - Running server info (port, PID, directory)
- `bookmarks.json` - Saved directory bookmarks
- `launcher.log` - Debug log from app launcher
- `root_path` - Current root for pumadev mode

## Common Development Tasks

### Rebuilding the Gem
```bash
gem build markymark.gemspec
gem install markymark-0.1.0.gem
```

### Reinstalling the App
```bash
echo 'y' | markymark --install-app
xattr -cr ~/Applications/Markymark.app  # Clear quarantine
```

### Testing the Launcher
```bash
# Clear log and test
: > ~/.markymark/launcher.log
open -a ~/Applications/Markymark.app /path/to/file.md
cat ~/.markymark/launcher.log
```

### Debugging App Issues
1. Check `~/.markymark/launcher.log` for helper script output
2. Verify paths in `~/Applications/Markymark.app/Contents/MacOS/markymark-helper`
3. Test Swift launcher receives files: the log should show "Helper called with: /path/to/file"

## Key Implementation Details

### File Discovery
- Uses `Dir.glob` with fallback to manual traversal for permission-protected directories
- Skips `~/Library/` and other protected macOS directories
- Groups files by directory with accordion UI

### Markdown Rendering
- Kramdown with GFM (GitHub Flavored Markdown) parser
- Rouge for syntax highlighting
- Mermaid.js for diagrams (client-side rendering)
- UTF-8 encoding for international character support

### Org-mode Support
markymark also renders `.org` files with an AST-first architecture:

**Modules:**
| File | Purpose |
|------|---------|
| `lib/markymark/org/parser.rb` | Wraps org-ruby, builds custom AST |
| `lib/markymark/org/renderer.rb` | Renders AST to semantic HTML |
| `lib/markymark/org/id_generator.rb` | Generates stable, deterministic IDs |
| `lib/markymark/org/nodes/*.rb` | AST node classes (Document, Heading, Link, etc.) |

**Supported Features:**
- Headings with TODO states, tags, and properties drawers
- Inline formatting: bold, italic, code, verbatim, strikethrough, underline
- Source blocks with Rouge syntax highlighting and named blocks
- Tables with inline formatting support
- Lists with checkboxes and progress indicators
- Footnotes with bidirectional linking
- Quote and example blocks

**Linking System (Emacs-style):**
- Internal links: `[[*Heading]]`, `[[#custom-id]]`
- Cross-document: `[[file:doc.org::*Heading]]`, `[[file:doc.org::#id]]`
- Search links: `[[file:doc.org::search term]]` (highlights first match)

**Interactive Features:**
- Section folding (click ▼ or double-click, Shift+Tab for all)
- Floating Table of Contents with scroll tracking
- Tag index with jump navigation
- Fold state persisted in localStorage

**Documentation:**
- `docs/ORG_MODE_GUIDE.org` - Feature showcase and guide
- `docs/SUPPORTED_FEATURES.org` - Complete feature reference with status

### Toolbar Actions
The header toolbar includes:
- **Copy file path** - Copies the full filesystem path of the current file to clipboard (useful for sharing with other tools/agents)
- **Edit file** - Opens the current file in an external editor
- **Present (org-reveal)** - For `.org` files with `#+REVEAL_` headers, exports and opens presentation via `emacsclient`
- **Theme toggle** - Switches between light and dark mode

### Org-reveal Integration
The present button (🎬) appears only for org files containing org-reveal headers (`#+REVEAL_ROOT:`, `#+REVEAL_THEME:`, etc.).

**How it works:**
1. Detection: `ServerSimple.org_reveal_file?` scans first 50 lines for `#+REVEAL_` pattern
2. Export: `POST /present` runs `emacsclient -e '(progn (find-file "...") (org-reveal-export-to-html))'`
3. Opens: Exported HTML opened in default browser

**Requirements:**
- Emacs server running (`M-x server-start`)
- `ox-reveal` package installed in Emacs

### Editor Configuration
The edit button opens files in an external editor. Editor resolution order:
1. `MARKYMARK_EDITOR_<EXT>` - Filetype-specific override (e.g., `MARKYMARK_EDITOR_ORG=emacs`)
2. `MARKYMARK_EDITOR` - General markymark override
3. `VISUAL` - Standard Unix visual editor
4. `EDITOR` - Standard Unix editor
5. Platform default: `open` (macOS), `xdg-open` (Linux), `start` (Windows)

Example configuration:
```bash
# Use VS Code for markdown, Emacs for org files
export MARKYMARK_EDITOR_MD="code"
export MARKYMARK_EDITOR_ORG="emacs"
```

### Ruby Environment Setup
The macOS app helper script bakes in:
- `RUBY_PATH` - Full path to Ruby executable
- `MARKYMARK_PATH` - Path to markymark executable in gem
- `GEM_HOME` / `GEM_PATH` - Gem environment for require resolution
- `RUBYLIB` - Path to markymark lib directory

This is necessary because the Swift launcher doesn't inherit shell environment (no RVM/rbenv setup).

## Dependencies

- `sinatra` ~> 3.0 - Web framework
- `puma` ~> 6.0 - Web server
- `kramdown` ~> 2.4 - Markdown parser
- `kramdown-parser-gfm` - GitHub Flavored Markdown
- `org-ruby` ~> 0.9 - Org-mode parser (provides initial parsing for AST)
- `rouge` ~> 4.0 - Syntax highlighting
- `listen` ~> 3.8 - File watching (for future live reload)
- `launchy` ~> 2.5 - Browser opening

## Platform Support

**The core markdown viewer works on any platform with Ruby** (macOS, Linux, Windows).

The **native app integration** (double-click to open, cmd-click in terminal) is **macOS only**. Cross-platform native integration contributions welcome:
- **Linux**: Need `.desktop` file integration, `xdg-open` support
- **Windows**: Need registry associations, shell integration
