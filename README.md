# markymark

<p align="center">
  <img src="assets/marky-mark-dj.jpg" alt="Marky Mark spinning docs" width="600"/>
</p>

> *Say hi to your docs* 👋
> **Your personal documentation DJ - spinning markdown into pure visual rhythm**

**markymark** is a lightweight local markdown documentation browser. Think of it as your personal documentation DJ - spinning up your markdown files with smooth GitHub-flavored rendering, Mermaid diagrams, and syntax highlighting. Simple, fast, and distraction-free.

## Features

- 🔄 **Smart directory switching** - Run `markymark` from any directory to switch existing server or start new one
- 📁 **Auto-discovery** - Recursively finds all your markdown files
- 📂 **Directory switching** - Browse and change your documentation root directory via the UI
- 🔖 **Bookmarks** - Save frequently-used directories for quick access (stored in `~/.markymark/bookmarks.json`)
- 🚀 **Quick shortcuts** - Jump to common locations (Home, Downloads, Work) from the browse page
- 🔗 **Symlink support** - Follows symlinks to documentation in other directories
- 🎨 **GitHub-Flavored Markdown** - Tables, task lists, syntax highlighting, you name it
- 📊 **Mermaid diagrams** - Flowcharts, sequence diagrams, and more render beautifully
- 🌙 **Dark/Light theme toggle** - Switch themes with one click, persisted in localStorage
- 🔖 **Bookmarkable URLs** - Share links to specific docs
- 🖼️ **Image support** - Place images in an `assets/` folder for rendering
- 🌐 **Pumadev integration** - Optional .test domain support for easier access

## Installation

```bash
gem install markymark
```

## Usage

```bash
# Browse current directory
markymark

# Browse specific directory
markymark ~/my-docs

# Custom port
markymark --port 8080

# Get help
markymark --help
```

The browser opens automatically and you're good to go. Press `Ctrl+C` to stop the server.

## How It Works

1. **Scans** your directory for `.md` and `.markdown` files
2. **Renders** markdown with full GitHub-Flavored Markdown support
3. **Displays** files in a clean, GitHub-style interface
4. **Switches** themes instantly with persistent localStorage

## Smart Directory Switching

markymark features intelligent server management:

- **Smart detection**: Running `markymark` from any directory automatically detects existing servers
- **Automatic switching**: If a server is running, it switches to your new directory without starting a new process
- **Port conflict handling**: If the default port is busy, markymark prompts you to start on an alternative port
- **Persistent tracking**: Server information stored in `~/.markymark/server.pid` for reliable detection

### Examples

```bash
# Start server in first directory
cd ~/docs/project-a
markymark

# From another directory, switch the same server
cd ~/docs/project-b
markymark  # Automatically switches existing server to project-b
```

## Pumadev Integration

For those who prefer .test domains over remembering ports:

```bash
# View setup instructions
markymark --pumadev

# After setup, access via
http://markymark.test
```

**Note for Ruby Version Manager Users**: Install markymark in your global gemset of your default Ruby to ensure the command is available across all Ruby versions.

## Smart Defaults

- Automatically shows the first markdown file found
- Defaults to port 4545 (memorable and fewer conflicts)
- Theme preference persists across sessions
- Respects your directory structure

## Requirements

- Ruby >= 2.7

## Development

```bash
git clone https://github.com/fkchang/markymark.git
cd markymark
bundle install
```

Run locally:

```bash
bundle exec exe/markymark /path/to/docs
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fkchang/markymark.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

---

*Built with good vibrations* 🎵
