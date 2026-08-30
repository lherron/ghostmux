import Foundation
import GhosttyLib

struct NewPaneCommand: GhostmuxCommand {
  static let name = "new-pane"
  static let aliases = ["splitp", "split-pane"]
  static let help = commandHelp(
    """
    Usage:
      ghostmux new-pane [options]

    Options:
      -t <target>           Target terminal to split (UUID, title, or prefix)
                            Falls back to $GHOSTTY_SURFACE_UUID if not specified
      -d, --direction <dir> Split direction: left, right, up, down (default: right)
      --cwd <path>          Initial working directory for new pane
      --command <cmd>       Command to run after shell init
      --env <k=v>           Environment variable (repeatable)
      --no-focus            Create the pane without moving keyboard focus
      --keep-open           Hold the pane open after --command exits
      --json                Output JSON
      -h, --help            Show this help

    Directions:
      left    Split horizontally, new pane on the left
      right   Split horizontally, new pane on the right (default)
      up      Split vertically, new pane above
      down    Split vertically, new pane below

    Keep open:
      --keep-open requires --command. After the command exits the pane stays
      open, prints its exit status, and drops to an interactive shell so the
      scrollback is readable. Note that the pane then no longer disappears on
      command completion, so a caller polling for the surface to vanish as a
      completion signal will wait forever.

    Examples:
      ghostmux new-pane                           # Split right from focused pane
      ghostmux new-pane -d down                   # Split down from focused pane
      ghostmux new-pane -t 550e8400 -d left       # Split left from specific pane
      ghostmux new-pane -d down --cwd /tmp        # Split down with working directory
      ghostmux new-pane -d right --no-focus       # Split without stealing focus
      ghostmux new-pane --command 'make' --keep-open  # Hold the pane after exit
    """)

  static func run(context: CommandContext) throws {
    var direction = "right"
    var env: [String: String] = [:]

    let parsed = try parseCommandArguments(
      context.args,
      booleanFlags: ["--no-focus", "--keep-open"],
      valueFlags: ["-d", "--direction", "--cwd", "--command", "--env"]
    )
    if parsed.help {
      print(help)
      return
    }

    if let parsedDirection = parsed.value(forAny: ["-d", "--direction"]) {
      direction = parsedDirection.lowercased()
    }
    for pair in parsed.values(for: "--env") {
      guard let eqIndex = pair.firstIndex(of: "=") else {
        throw GhosttyError.message("env must be in KEY=VALUE form")
      }
      let key = String(pair[..<eqIndex])
      let value = String(pair[pair.index(after: eqIndex)...])
      if key.isEmpty {
        throw GhosttyError.message("env key must be non-empty")
      }
      env[key] = value
    }

    // Validate direction
    let validDirections = ["left", "right", "up", "down"]
    guard validDirections.contains(direction) else {
      throw GhosttyError.message(
        "invalid direction '\(direction)': must be left, right, up, or down")
    }

    let terminals = try context.client.listTerminals()
    let policy: SurfaceResolutionPolicy = .focusedTarget
    let parentId = try resolveSurfaceTarget(parsed.target, terminals: terminals, policy: policy).id

    // Create the split
    let location = "split:\(direction)"
    let request = CreateTerminalRequest(
      location: location,
      workingDirectory: parsed.value(for: "--cwd"),
      command: try resolvedCommand(parsed),
      env: env.isEmpty ? nil : env,
      parent: parentId,
      focus: parsed.hasFlag("--no-focus") ? false : nil
    )

    let terminal = try context.client.createTerminal(request: request)

    if parsed.json {
      writeJSON(terminal.toJsonDict())
      return
    }

    print(terminalSummary(terminal))
  }
}
