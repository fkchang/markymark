# markymark

<p align="center">
  <img src="assets/marky-mark-dj.jpg" alt="Marky Mark spinning docs" width="600"/>
</p>

> *Say hi to your docs* 👋
> **Your personal documentation DJ - spinning markdown into pure visual rhythm**

**markymark** is a local markdown documentation browser with live reload. Think of it as your personal documentation DJ - spinning up your markdown files with smooth GitHub-flavored rendering, Mermaid diagrams, syntax highlighting, and real-time updates. No more alt-tabbing between your editor and browser. Just good vibes and good docs.

## Features

- 📁 **Auto-discovery** - Recursively finds all your markdown files
- 🌳 **Expandable file tree** - Navigate your docs like a pro
- 🎨 **GitHub-Flavored Markdown** - Tables, task lists, syntax highlighting, you name it
- 📊 **Mermaid diagrams** - Flowcharts, sequence diagrams, and more render beautifully
- ⚡ **Live reload** - Files update automatically when you save (SSE-powered, no polling needed)
- 🌙 **Dark/Light themes** - Easy on the eyes, day or night
- 🔖 **Bookmarkable URLs** - Share links to specific docs
- 🖼️ **Image support** - Relative paths just work

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
2. **Watches** for file changes, additions, and deletions
3. **Renders** markdown with full GitHub-Flavored Markdown support
4. **Updates** your browser in real-time via Server-Sent Events
5. **Looks good** with clean GitHub-style aesthetics and theme support

## Smart Defaults

- Automatically shows `README.md` from the root directory if it exists
- Otherwise shows the first markdown file it finds
- Defaults to port 4567 (Sinatra's favorite)
- Auto-detects your system's dark/light mode preference

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
