import Foundation
import GhosttyLib

struct ResizePaneCommand: GhostmuxCommand {
  static let name = "resize-pane"
  static let aliases = ["resizep"]
  static let help = commandHelp(
    """
      Usage:
        ghostmux resize-pane [options]

      Options:
        -t <target>           Target terminal (UUID, title, or prefix)
                              Falls back to $GHOSTTY_SURFACE_UUID if not specified
        -d, --direction <dir> Resize direction: left, right, up, down (required)
        -a, --amount <pixels> Amount to resize in pixels (default: 50)
        --json                Output JSON
        -h, --help            Show this help

      Directions:
        left    Shrink pane from left edge (or expand neighbor)
        right   Expand pane from right edge (or shrink neighbor)
        up      Shrink pane from top edge (or expand neighbor)
        down    Expand pane from bottom edge (or shrink neighbor)

      Examples:
        ghostmux resize-pane -d right -a 100     # Expand right by 100px
        ghostmux resize-pane -d up -a 50         # Shrink from top by 50px
        ghostmux resize-pane -t 550e8400 -d down # Expand down by default 50px
    """)

  static func run(context: CommandContext) throws {
    var direction: String?
    var amount: Int = 50

    let parsed = try parseCommandArguments(
      context.args,
      valueFlags: ["-d", "--direction", "-a", "--amount"]
    )
    if parsed.help {
      print(help)
      return
    }

    direction = parsed.value(forAny: ["-d", "--direction"])?.lowercased()
    if let rawAmount = parsed.value(forAny: ["-a", "--amount"]) {
      guard let parsedAmount = Int(rawAmount), parsedAmount > 0 else {
        throw GhosttyError.message("amount must be a positive integer")
      }
      amount = parsedAmount
    }

    // Validate direction
    guard let direction else {
      throw GhosttyError.message("resize-pane requires -d <direction>")
    }

    let validDirections = ["left", "right", "up", "down"]
    guard validDirections.contains(direction) else {
      throw GhosttyError.message(
        "invalid direction '\(direction)': must be left, right, up, or down")
    }

    let terminals = try context.client.listTerminals()
    let policy: SurfaceResolutionPolicy = .regularTarget
    let targetTerminal = try resolveSurfaceTarget(
      parsed.target, terminals: terminals, policy: policy)

    // Execute resize action
    let action = "resize_split:\(direction),\(amount)"
    try context.client.executeAction(terminalId: targetTerminal.id, action: action)

    if parsed.json {
      writeJSON(["success": true, "direction": direction, "amount": amount])
      return
    }

    print("resized \(direction) by \(amount)px")
  }
}
