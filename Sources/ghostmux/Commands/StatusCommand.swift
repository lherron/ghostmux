import Foundation
import GhosttyLib

struct StatusCommand: GhostmuxCommand {
  static let name = "status"
  static let aliases: [String] = []
  static let help = commandHelp(
    """
      Usage:
        ghostmux status

      Options:
        --json                Output JSON
        -h, --help            Show this help
    """)

  static func run(context: CommandContext) throws {
    let parsed = try parseCommandArguments(context.args)
    if parsed.help {
      print(help)
      return
    }

    let available = context.client.isAvailable()
    if parsed.json {
      writeJSON(["available": available])
      return
    }
    print("available: \(available)")
  }
}
