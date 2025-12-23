# Copy Path and Edit File Features

## Overview

Add two new toolbar buttons to markymark:
1. **Copy file path** - Copy the full filesystem path of the current file to clipboard
2. **Edit file** - Open the current file in a configurable editor

## Copy File Path Feature

### UI
- Button in header toolbar, styled consistently with theme toggle
- Icon: clipboard
- Tooltip: "Copy file path"
- Disabled when no file is selected

### Behavior
- Click copies full filesystem path (e.g., `/Users/fkchang/work/project/README.md`)
- Path computed from URL params: `dir` + `/` + `file`
- Brief visual feedback (icon changes to checkmark for 1-2 seconds)

### Implementation
- Client-side JavaScript in `simple.erb`
- Extract `dir` and `file` from URL query params, combine them
- No server changes needed

## Edit File Feature

### UI
- Button in header toolbar, next to copy button
- Icon: pencil
- Tooltip: "Edit file"
- Disabled when no file is selected

### Editor Resolution Order
1. `MARKYMARK_EDITOR_ORG` or `MARKYMARK_EDITOR_MD` (filetype-specific, based on extension)
2. `MARKYMARK_EDITOR` (general override)
3. `VISUAL`
4. `EDITOR`
5. Platform default: `open` (macOS), `xdg-open` (Linux), `start` (Windows)

### Server Endpoint
- `POST /edit` with `file` and `dir` params
- Server resolves editor using the lookup order above
- Spawns editor process detached (non-blocking)
- Returns success/error JSON

### Implementation
- New endpoint in `server_simple.rb`
- Helper method `resolve_editor(extension)` for the lookup logic
- Client-side: button click sends POST, shows brief feedback

## Files to Modify

| File | Changes |
|------|---------|
| `lib/views/simple.erb` | Add copy + edit buttons to header, add JavaScript handlers |
| `lib/markymark/server_simple.rb` | Add `POST /edit` endpoint, add `resolve_editor` helper |

## Security Considerations
- Validate file path is within allowed root (reuse existing `within_root?` check)
- Don't expose editor command in response
