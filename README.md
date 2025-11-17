# markymark

<p align="center">
  <img src="assets/marky-mark-dj.jpg" alt="Marky Mark spinning docs" width="600"/>
</p>

> *Say hi to your docs* 👋
> **Your personal documentation DJ - spinning markdown into pure visual rhythm**

**markymark** is a lightweight local markdown documentation browser. Think of it as your personal documentation DJ - spinning up your markdown files with smooth GitHub-flavored rendering, Mermaid diagrams, and syntax highlighting. Simple, fast, and distraction-free.

## Features

- 📁 **Auto-discovery** - Recursively finds all your markdown files
- 📂 **Directory switching** - Browse and change your documentation root directory via the UI
- 🎨 **GitHub-Flavored Markdown** - Tables, task lists, syntax highlighting, you name it
- 📊 **Mermaid diagrams** - Flowcharts, sequence diagrams, and more render beautifully
- 🌙 **Dark/Light theme toggle** - Switch themes with one click, persisted in localStorage
- 🔖 **Bookmarkable URLs** - Share links to specific docs
- 🖼️ **Image support** - Place images in an `assets/` folder for rendering

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

## Smart Defaults

- Automatically shows the first markdown file found
- Defaults to port 4567 (Sinatra's favorite)
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
