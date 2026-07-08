import Foundation
import GhosttyLib

struct ListSessionsCommand: GhostmuxCommand {
  static let name = "list-surfaces"
  static let aliases = ["list-sessions", "ls"]
  static let help = commandHelp(
    """
      Usage:
        ghostmux list-surfaces

      Options:
        --json                Output JSON

      List all terminals.
    """)

  static func run(context: CommandContext) throws {
    let parsed = try parseCommandArguments(context.args)
    if parsed.help {
      print(help)
      return
    }

    let terminals = try context.client.listTerminals()
    if parsed.json {
      let payload = ["terminals": terminals.map { $0.toJsonDict() }]
      writeJSON(payload)
      return
    }
    if terminals.isEmpty {
      print("(no terminals)")
      return
    }
    for terminal in terminals {
      print(terminalSummary(terminal))
    }
  }
}
