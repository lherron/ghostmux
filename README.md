# ghostmux

A Swift CLI for controlling [ScriptableGhostty](https://github.com/lherron/scriptable-ghostty) terminals via Unix Domain Socket.

## Requirements

- macOS 13+
- Swift 5.9+
- [ScriptableGhostty](https://github.com/lherron/scriptable-ghostty) app installed

## Installation

### From source

```bash
git clone https://github.com/lherron/ghostmux.git
cd ghostmux
just install
```

### Manual build

```bash
swift build -c release
cp .build/release/ghostmux ~/.local/bin/
```

## Usage

ghostmux communicates with ScriptableGhostty via a Unix Domain Socket at `~/Library/Application Support/Ghostty/api.sock`. The app is auto-launched if not running.

### Commands

```bash
# List all terminal surfaces
ghostmux list-surfaces

# Check API availability
ghostmux status

# Create a new terminal (created in the background by default — focus is NOT moved)
ghostmux new                              # New window (unfocused)
ghostmux new --focus                      # New window, move focus to it
ghostmux new --tab                        # New tab (unfocused)
ghostmux new --tab --focus                # New tab, move focus to it
ghostmux new --cwd /path/to/dir           # With working directory
ghostmux new --command "vim file.txt"     # Run command
ghostmux new --title "My Terminal"        # With title

# Create and arrange panes
ghostmux new-pane -d right                # Split from focused pane
ghostmux panes-grid 3x2                   # Create a 3x2 grid
ghostmux get-pane-size -t <target>        # Get pane dimensions
ghostmux resize-pane -t <target> -d right -a 100
ghostmux equalize-panes -t <target>

# Send text to terminal (appends Enter by default)
ghostmux send-keys <target> "echo hello"
ghostmux send-keys <target> "ls -la" --no-enter
ghostmux send-keys <target> --literal "exact text"

# Send a single key (no Enter appended)
ghostmux send-key <target> C-c            # Ctrl+C
ghostmux send-key <target> Tab
ghostmux send-key <target> Escape

# Set terminal title
ghostmux set-title <target> "New Title"

# Set background color
ghostmux set-bg <target> --color "#1a1b26"
ghostmux set-bg <target> --rgb 26,27,38

# Raise a terminal window
ghostmux focus -t <target>

# Attach host session metadata
ghostmux attach-host-session -t <target> animata-host://workspace/animata:center

# Control status bar
ghostmux statusbar <target> --left "Status"
ghostmux statusbar <target> --center "Center" --right "Right"
ghostmux statusbar <target> --hide
ghostmux statusbar <target> --show

# Manage metadata
ghostmux metadata get -t <target>
ghostmux metadata set -t <target> '{"key":"value"}'
ghostmux metadata delete -t <target>

# Capture terminal content
ghostmux capture-pane <target>            # Full scrollback
ghostmux capture-pane <target> --visible  # Visible area only
ghostmux capture-pane <target> -S -10     # Last 10 lines
ghostmux capture-pane <target> -S 0 -E 50 # Lines 0-50

# Capture terminal screenshot
ghostmux screenshot <target>              # Writes PNG under /tmp/ghostmux-screenshots
ghostmux screenshot <target> -o pane.png  # Writes PNG to a specific path
ghostmux screenshot <target> --json       # Writes PNG and prints metadata

# Stream terminal output (real-time)
ghostmux stream-surface <target>
ghostmux stream-surface <target> --raw    # Raw bytes

# Close a terminal
ghostmux kill-surface <target> --force
```

### Target Resolution

The `<target>` can be:
- Full UUID: `550e8400-e29b-41d4-a716-446655440000`
- UUID prefix: `550e84`
- Friendly name/slug from `list-surfaces --json`: `swift-falcon`
- Title match: `"My Terminal"`
- Omitted: Uses `$GHOSTTY_SURFACE_UUID` environment variable

`ghostmux screenshot` intentionally accepts UUIDs, UUID prefixes, and friendly
names/slugs. It does not fall back to title substring matching.

### JSON Output

Most commands support `--json` for machine-readable output:

```bash
ghostmux list-surfaces --json
ghostmux new --json
```

## Environment Variables

- `GHOSTTY_API_SOCKET` - Custom socket path (default: `~/Library/Application Support/Ghostty/api.sock`)
- `GHOSTTY_SURFACE_UUID` - Default target terminal UUID

## Building ScriptableGhostty

For convenience, you can build and install ScriptableGhostty from this repo:

```bash
just install-ghostty
```

This requires the [scriptable-ghostty](https://github.com/lherron/scriptable-ghostty) repository to be cloned as a sibling directory.

## License

MIT
