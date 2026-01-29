# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
just build           # Debug build
just build-release   # Release build
just install         # Build release and install to ~/.local/bin
just test            # Run smoke tests (requires running ScriptableGhostty)
just format          # Format Swift code with swift-format
just clean           # Clean build artifacts
```

## Architecture

ghostmux is a Swift CLI for controlling [ScriptableGhostty](https://github.com/lherron/scriptable-ghostty) terminals via Unix Domain Socket. It provides two executables: `ghostmux` (terminal control) and `ghostchat` (inter-agent messaging).

### Package Structure

- **GhosttyLib** - Shared library containing:
  - `GhosttyClient` - UDS client with JSON-over-socket protocol (4-byte length prefix + JSON payload)
  - `Models` - `Terminal`, `CreateTerminalRequest`, `KeyStroke` data types
  - `KeyStroke` - Key parsing for special keys (C-c, Tab, etc.) and modifier combinations
  - `Utils` - Target resolution, socket path, JSON output helpers

- **ghostmux** - Main CLI executable with command pattern:
  - `Command.swift` - `GhostmuxCommand` protocol and `CommandContext`
  - `Commands/` - Individual command implementations (each command is a struct conforming to `GhostmuxCommand`)

- **ghostchat** - Inter-agent messaging CLI:
  - Uses `NameGenerator` for deterministic friendly names from UUIDs
  - Protocol: `[ghostchat:<sender-name>] <message>`

### UDS Protocol

Communication with ScriptableGhostty uses a custom JSON-over-socket protocol:
1. Requests: 4-byte big-endian length + JSON envelope with `version`, `method`, `path`, optional `query` and `body`
2. Responses: 4-byte big-endian length + JSON with `status` and `body`
3. API version: `v2`
4. Socket path: `~/Library/Application Support/Ghostty/api.sock`

### Adding New Commands

1. Create `Sources/ghostmux/Commands/YourCommand.swift`
2. Implement `GhostmuxCommand` protocol with `name`, `aliases`, `help`, and `run(context:)`
3. Register in `commandTypes` array in `main.swift`
