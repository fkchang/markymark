# Changelog

All notable changes to this project will be documented in this file.

## [0.1.1] - 2025-12-19

### Fixed
- `markymark init -y` flag now works correctly (was failing with "invalid option")

## [0.1.0] - 2025-12-19

### Added
- Initial release
- GitHub-Flavored Markdown rendering with Kramdown
- Mermaid diagram support
- Syntax highlighting with Rouge
- Dark/Light theme toggle with localStorage persistence
- Accordion file organization grouped by directory
- Directory browser with bookmarks
- Smart directory switching without server restart
- `markymark <filename>` to open specific files directly
- **macOS Native Integration**:
  - `markymark init` setup wizard
  - Markymark.app installation to ~/Applications
  - Double-click `.md` files in Finder
  - Cmd-click paths in iTerm
  - `open` command support
  - Default file handler registration via duti
- Pumadev integration for `.test` domain support
- Standalone server mode on port 4545

### Requirements
- Ruby >= 2.7
- macOS native integration requires Xcode Command Line Tools
