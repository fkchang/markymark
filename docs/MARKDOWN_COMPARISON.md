# MarkyMark Org-mode Support

**Author:** Forrest Chang

*This is a Markdown version of [ORG_MODE_GUIDE.org](ORG_MODE_GUIDE.org) to demonstrate the differences between the formats.*

---

## Introduction to MarkyMark

<!-- No equivalent to org-mode's :PROPERTIES: drawer -->
<!-- No CUSTOM_ID - we'd need manual HTML: <a id="introduction"></a> -->

MarkyMark is a lightweight documentation viewer designed for developers who work with markup-based documentation. It provides:

- **Real-time file watching** with automatic refresh
- **Syntax highlighting** via Rouge
- **Mermaid diagram** rendering
- **Dark/light theme** toggle
- **Directory browsing** with bookmarks

And now, **org-mode support** - bringing the power of Emacs' org-mode to your browser.

### Why Another Documentation Viewer?

<!-- No properties, no CUSTOM_ID without manual HTML -->

Most documentation viewers treat files as read-only outputs. MarkyMark treats them as *living documents* that you edit alongside your code. The viewer updates instantly as you write.

## Org-mode Support

<!-- In org-mode, this would be: * DONE Org-mode Support :feature:v1: -->
<!-- Markdown has no TODO states - we have to fake it with emoji or badges -->

**Status:** DONE | **Tags:** feature, v1 | **Completed:** 2024-12-22

<!-- Notice we had to manually add status/tags as text. Not structured data. -->

Org-mode is Emacs' powerful markup language for notes, documentation, and literate programming. MarkyMark now renders `.org` files with full support for the features that make org-mode superior to Markdown for technical documentation.

### What Makes Org-mode Powerful?

Org-mode wasn't designed as "just another markup language." It was designed as a *structured document format* with:

1. **Metadata everywhere** - Properties, tags, TODO states
2. **Stable references** - CUSTOM_ID for permanent links
3. **Named elements** - Code blocks you can reference by name
4. **Native task tracking** - TODO/DONE built into headings

This guide demonstrates these features *by using them*.

## Feature Showcase

<!-- Org-mode: * Feature Showcase :demo: -->
<!-- Tags must be manually added as text in Markdown -->

**Tags:** demo

### TODO States and Tags

<!-- Org-mode headings naturally carry TODO state and tags -->
<!-- Markdown requires manual text or badges -->

**Tags:** workflow

Every heading can have a TODO state. This isn't just visual decoration - it's *structured data* that tools can query and manipulate.

#### TODO: Implement custom TODO states

<!-- In org: *** TODO Implement custom TODO states :enhancement: -->

**Tags:** enhancement

Allow users to define their own states like `WAITING`, `REVIEW`, `BLOCKED`.

#### DONE: Basic TODO/DONE support

**Tags:** core

The renderer displays TODO states as colored badges.

#### DONE: Tag rendering

**Tags:** core

Tags appear as pills on the right side of headings.

---

### Properties Drawers

<!-- Org-mode has this amazing feature - properties attached to any heading -->
<!-- Markdown only has YAML frontmatter, and only at document level -->

**Author:** Forrest Chang | **Created:** 2024-12-22 | **Category:** documentation

<!-- In org-mode, you'd expand a "Properties" toggle to see these -->
<!-- In Markdown, we just have to inline them as text -->

Properties drawers attach *structured metadata* to any heading. In org-mode, you'd click "Properties" to expand a collapsible drawer.

Common uses:
- `CUSTOM_ID` - Stable anchor for linking
- `CREATED` / `MODIFIED` - Timestamps
- `AUTHOR` - Attribution
- `CATEGORY` - Classification

In Markdown, you'd need YAML frontmatter (document-level only) or HTML comments (not rendered).

---

### Source Code Blocks

<!-- Org-mode blocks can have NAMES that display as captions -->
<!-- Markdown has no equivalent -->

```ruby
# A simple greeting in Ruby
def greet(name)
  puts "Hello, #{name}!"
end

greet("Org-mode")
```

<!-- The block above has NO NAME in Markdown -->
<!-- In org-mode, we'd have: #+NAME: hello-world-example -->
<!-- Which renders a caption and enables referencing -->

**Note:** In org-mode, this block would have the name `hello-world-example` and display a caption. Markdown's fenced code blocks are anonymous.

---

### Tables

| Feature | Org-mode | Markdown |
|---------|----------|----------|
| TODO states | Native | None |
| Tags | Native | None |
| Properties | Native | YAML[^1] |
| Named blocks | Native | None |
| Checkboxes | Native | GFM only |
| Footnotes | Native | Extension |
| Stable IDs | CUSTOM_ID | Manual |

<!-- Tables work similarly, but org's |--+--| syntax auto-aligns in Emacs -->

---

### Lists with Checkboxes

**MarkyMark Org-mode Implementation Checklist:**

<!-- GFM supports checkboxes, but not all Markdown parsers do -->

- [x] AST-first parser design
- [x] Stable ID generation
- [x] Heading with TODO/tags/properties
- [x] Source blocks with names
- [x] Tables
- [x] Lists with checkboxes
- [x] Footnotes with backlinks
- [ ] Nested list improvements
- [ ] Custom TODO states
- [ ] Drawer types beyond PROPERTIES

<!-- Note: GitHub Flavored Markdown (GFM) supports this -->
<!-- But standard Markdown doesn't -->

---

### Inline Formatting

| Syntax | Renders As | Org-mode Equivalent |
|--------|------------|---------------------|
| `**bold**` | **bold** | `*bold*` |
| `*italic*` | *italic* | `/italic/` |
| `` `code` `` | `code` | `~code~` or `=verbatim=` |
| `~~strike~~` | ~~strikethrough~~ | `+strike+` |
| ??? | <u>underline</u> | `_underline_` |

<!-- Markdown has NO native underline - you need HTML -->
<!-- Org-mode also distinguishes ~code~ from =verbatim= -->

**Note:** Markdown has no native underline syntax. You must use raw HTML: `<u>underline</u>`.

---

### Footnotes

Footnotes in org-mode are first-class citizens with bidirectional linking[^2].

When you click a footnote reference, you jump to the definition. The definition includes a backlink to return to the reference point. This is automatic - no manual anchor management.

Markdown's footnote support (when available) varies by implementation. GitHub doesn't support them in READMEs. Many parsers don't support them at all.

<!-- Note: This Markdown file uses footnotes, but they may not render -->
<!-- depending on the Markdown parser being used -->

---

### Quote and Example Blocks

> Org-mode is not just a markup language. It's a way of thinking about documents as *structured data* that happens to render nicely.
>
> --- Every Emacs user, eventually

<!-- Org-mode has separate QUOTE and EXAMPLE blocks -->
<!-- EXAMPLE preserves exact whitespace -->
<!-- Markdown only has blockquotes (>) and code blocks -->

```
  This text preserves
    its exact
      indentation
        and spacing.
```

<!-- We had to use a code block to preserve whitespace -->
<!-- Org-mode's EXAMPLE block is semantically different from code -->

---

## Architecture

MarkyMark's org-mode support uses an **AST-first architecture**:

```
                    ┌─────────────┐
   .org file ──────▶│  org-ruby   │──────▶ Parsed headlines
                    └─────────────┘        & body lines
                           │
                           ▼
                    ┌─────────────┐
                    │   Parser    │──────▶ MarkyMark AST
                    └─────────────┘        (Document, Heading,
                           │                Paragraph, etc.)
                           ▼
                    ┌─────────────┐
                    │  Renderer   │──────▶ Semantic HTML
                    └─────────────┘        with stable IDs
```

This design enables:
- **Stable IDs** derived from heading paths and CUSTOM_ID
- **Semantic HTML** with proper `<section>`, `<details>`, etc.
- **Future extensibility** for additional features

### Node Types

| Node | Purpose |
|------|---------|
| Document | Root container with title/properties |
| Heading | Section with level, TODO, tags |
| Paragraph | Block of inline content |
| SrcBlock | Named source code |
| ExampleBlock | Verbatim text |
| QuoteBlock | Block quotation |
| Table | Tabular data |
| List | Ordered/unordered list |
| ListItem | Item with optional checkbox |
| FootnoteRef | Reference to footnote |
| FootnoteDef | Footnote definition |
| Link | Hyperlink with description |
| Text, Bold... | Inline formatting |

---

## Future Roadmap

<!-- In org-mode, these would be TODO headings with priority properties -->

### TODO: Custom TODO States

**Priority:** B

Support #+TODO: and #+SEQ_TODO: for custom workflow states.

### TODO: Additional Drawer Types

**Priority:** C

Currently only PROPERTIES drawer is supported. Add support for:
- LOGBOOK (time tracking)
- Custom named drawers

### TODO: Upstream Contribution

**Priority:** A

The AST design could benefit the broader org-ruby ecosystem. GitHub uses org-ruby for rendering .org files - contributing AST support upstream would:

1. Improve org-mode rendering on GitHub
2. Benefit all org-ruby users
3. Share maintenance with the community

---

## Comparison Summary

See [ORG_MODE_GUIDE.org](ORG_MODE_GUIDE.org) for the org-mode version of this document.

| Capability | Org-mode | Markdown |
|------------|----------|----------|
| Task states | `* TODO Heading` | Manual (badges/emoji) |
| Tags | `* Heading :tag:` | None |
| Heading metadata | Properties drawer | None (YAML is global) |
| Stable anchors | `CUSTOM_ID` property | Manual `<a id="">` |
| Named code blocks | `#+NAME: block-name` | None |
| Checkboxes | `- [ ] item` | GFM only |
| Footnotes | Native with backlinks | Extension, varies |
| Underline | `_underline_` | None (use HTML) |
| Verbatim vs Code | `=verbatim=` vs `~code~` | Both use backticks |

---

## Getting Started

To use org-mode with MarkyMark:

1. Create a `.org` file in your documentation directory
2. Run `markymark` to start the server
3. Your org files appear alongside markdown files
4. Edit in your favorite editor - changes appear instantly

```bash
# Install markymark
gem install markymark

# Start viewing documentation
cd your-project
markymark
```

Links between `.org` and `.md` files work seamlessly. Use [relative links](../README.md) to connect your documentation.

---

## Footnotes

[^1]: YAML frontmatter only works at document level and isn't part of standard Markdown.

[^2]: This is a footnote demonstrating bidirectional linking. In org-mode, you'd see a backlink arrow to return to where you were reading.

---

## What This File Demonstrates

This Markdown file attempts to replicate [ORG_MODE_GUIDE.org](ORG_MODE_GUIDE.org). Notice:

1. **No TODO states** - We used text/badges instead of semantic states
2. **No tags on headings** - We added them as text manually
3. **No properties** - We inlined metadata that would be in drawers
4. **No named blocks** - Our code blocks are anonymous
5. **No stable IDs** - Would need manual `<a id="">` HTML
6. **Footnotes may not render** - Depends on parser support
7. **HTML comments everywhere** - Explaining the workarounds

The org-mode version is more *semantic* - the structure is in the format, not manually added text.
