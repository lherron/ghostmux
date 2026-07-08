import Foundation
import GhosttyLib

struct FocusCommand: GhostmuxCommand {
  static let name = "focus"
  static let aliases: [String] = []
  static let help = commandHelp(
    """
      Usage:
        ghostmux focus -t <target> [options]

      Raise the target terminal's window to the foreground.

      Options:
        -t <target>           Target terminal (UUID, title, or UUID prefix)
                              Falls back to $GHOSTTY_SURFACE_UUID if not specified
        --json                Output JSON
        -h, --help            Show this help
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

    try context.client.focusTerminal(terminalId: targetTerminal.id)
    if parsed.json {
      writeJSON(["success": true])
    }
  }
}
