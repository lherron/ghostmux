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

# Create a new terminal
ghostmux new                              # New window
ghostmux new --location tab               # New tab
ghostmux new --location split-right       # Split right
ghostmux new --location split-down        # Split down
ghostmux new --cwd /path/to/dir           # With working directory
ghostmux new --command "vim file.txt"     # Run command
ghostmux new --title "My Terminal"        # With title

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

# Control status bar
ghostmux statusbar <target> --left "Status"
ghostmux statusbar <target> --center "Center" --right "Right"
ghostmux statusbar <target> --hide
ghostmux statusbar <target> --show

# Capture terminal content
ghostmux capture-pane <target>            # Full scrollback
ghostmux capture-pane <target> --visible  # Visible area only
ghostmux capture-pane <target> -S -10     # Last 10 lines
ghostmux capture-pane <target> -S 0 -E 50 # Lines 0-50

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
- Title match: `"My Terminal"`
- Omitted: Uses `$GHOSTTY_SURFACE_UUID` environment variable

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
