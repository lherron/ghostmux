import Foundation
import GhosttyLib

struct KillSurfaceCommand: GhostmuxCommand {
  static let name = "kill-surface"
  static let aliases = ["close-surface", "delete-surface"]
  static let help = commandHelp(
    """
      Usage:
        ghostmux kill-surface -t <target> [options]

      Options:
        -t <target>           Target terminal (UUID, title, or UUID prefix)
                              Falls back to $GHOSTTY_SURFACE_UUID if not specified
        --confirm             Show confirmation dialog
        --force               Bypass confirmation dialog
        --json                Output JSON
        -h, --help            Show this help
    """)

  static func run(context: CommandContext) throws {
    let parsed = try parseCommandArguments(
      context.args,
      booleanFlags: ["--confirm", "--force"]
    )
    if parsed.help {
      print(help)
      return
    }

    let confirm = parsed.hasFlag("--confirm")
    let force = parsed.hasFlag("--force")
    if confirm && force {
      throw GhosttyError.message("kill-surface does not allow both --confirm and --force")
    }

    let policy: SurfaceResolutionPolicy = .regularTarget
    let targetTerminal = try resolveSurfaceTarget(
      parsed.target, client: context.client, policy: policy)

    try context.client.deleteTerminal(terminalId: targetTerminal.id, confirm: confirm && !force)
    if parsed.json {
      writeJSON(["success": true])
    }
  }
}
