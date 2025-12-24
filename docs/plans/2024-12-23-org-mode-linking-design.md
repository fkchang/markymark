# Org-mode Linking & Navigation Design

**Date**: 2024-12-23
**Status**: Approved, implementing

## Overview

Enhance MarkyMark's org-mode support with Emacs-style internal and cross-document linking, enabling seamless navigation between org documents.

## Link Syntax Support

### Internal Links (same document)

| Syntax | Behavior |
|--------|----------|
| `[[*Heading Text]]` | Jump to heading by text match |
| `[[#custom-id]]` | Jump to heading by CUSTOM_ID |
| `[[Heading Text]]` | Fuzzy match (heading or CUSTOM_ID) |

### Cross-Document Links

| Syntax | Behavior |
|--------|----------|
| `[[file:other.org]]` | Open document |
| `[[file:other.org::*Heading]]` | Open + jump to heading |
| `[[file:other.org::#custom-id]]` | Open + jump to CUSTOM_ID |
| `[[file:other.org::search text]]` | Open + highlight search match |

### With Descriptions

```org
[[file:other.org::*Intro][See the introduction]]
```

## URL Generation

| Link Type | Generated URL |
|-----------|---------------|
| `[[*Heading]]` | `#heading-slug` |
| `[[#custom-id]]` | `#custom-id` |
| `[[file:doc.org]]` | `?file=doc.org&dir=...` |
| `[[file:doc.org::*Heading]]` | `?file=doc.org&dir=...#heading-slug` |
| `[[file:doc.org::#id]]` | `?file=doc.org&dir=...#id` |
| `[[file:doc.org::search]]` | `?file=doc.org&dir=...&search=search` |

## Implementation

### 1. Enhanced Link Node

```ruby
class Link < Base
  attr_reader :url, :description, :anchor_type, :anchor_value

  def initialize(url:, description: nil, anchor_type: nil, anchor_value: nil)
    @url = url
    @description = description
    @anchor_type = anchor_type    # :heading, :custom_id, :search, nil
    @anchor_value = anchor_value
  end

  def internal?
    url.nil? || url.empty? || url.start_with?('#', '*')
  end

  def cross_doc?
    url&.match?(/\.(org|md)($|::)/)
  end
end
```

### 2. Parser Changes

Parse link target and anchor separately:
- `[[file:doc.org::*Heading]]` → url: `file:doc.org`, anchor_type: `:heading`, anchor_value: `Heading`
- `[[*Local Heading]]` → url: nil, anchor_type: `:heading`, anchor_value: `Local Heading`

### 3. Renderer Changes

```ruby
def render_link(node)
  case
  when internal_link?(node)
    render_internal_link(node)
  when cross_doc_link?(node)
    render_cross_doc_link(node)
  else
    render_external_link(node)
  end
end
```

### 4. Search Highlighting

JavaScript handles `?search=term` parameter:
1. Find first occurrence in document
2. Scroll to match
3. Wrap in `<mark class="org-search-highlight">`
4. Fade highlight after 3 seconds

### 5. Broken Link Handling

Console warning during render (non-blocking). Visual indicators can be added later.

## Files Modified

- `lib/markymark/org/nodes/link.rb` - Add anchor fields
- `lib/markymark/org/parser.rb` - Parse anchor syntax
- `lib/markymark/org/renderer.rb` - Generate correct URLs
- `lib/views/simple.erb` - Search highlight JS/CSS

## Testing

- Internal heading links resolve correctly
- Cross-document links include proper query params
- Search parameter triggers highlighting
- Relative paths resolve correctly
- Broken links warn but don't fail
