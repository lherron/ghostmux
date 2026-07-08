import Foundation
import GhosttyLib

struct EqualizePanesCommand: GhostmuxCommand {
  static let name = "equalize-panes"
  static let aliases = ["equalize", "eq"]
  static let help = commandHelp(
    """
      Usage:
        ghostmux equalize-panes [options]

      Options:
        -t <target>   Target terminal (UUID, title, or prefix)
                      Falls back to $GHOSTTY_SURFACE_UUID if not specified
        --json        Output JSON
        -h, --help    Show this help

      Description:
        Makes all panes in the current window equal size by adjusting split ratios
        based on the number of panes in each split direction.

      Examples:
        ghostmux equalize-panes                  # Equalize from focused pane
        ghostmux equalize-panes -t 550e8400      # Equalize from specific pane
    """)

  static func run(context: CommandContext) throws {
    let parsed = try parseCommandArguments(context.args)
    if parsed.help {
      print(help)
      return
    }

    let terminals = try context.client.listTerminals()
    let policy: SurfaceResolutionPolicy = .regularTarget
    let targetTerminal = try resolveSurfaceTarget(
      parsed.target, terminals: terminals, policy: policy)

    // Execute equalize action
    try context.client.executeAction(terminalId: targetTerminal.id, action: "equalize_splits")

    if parsed.json {
      writeJSON(["success": true])
      return
    }

    print("panes equalized")
  }
}
