import Foundation
import GhosttyLib

struct SetTitleCommand: GhostmuxCommand {
  static let name = "set-title"
  static let aliases: [String] = []
  static let help = commandHelp(
    """
      Usage:
        ghostmux set-title -t <target> <title>

      Options:
        -t <target>           Target terminal (UUID, title, or UUID prefix)
                              Falls back to $GHOSTTY_SURFACE_UUID if not specified
        --json                Output JSON
        -h, --help            Show this help
    """)

  static func run(context: CommandContext) throws {
    let parsed = try parseCommandArguments(
      context.args,
      positionals: .collect,
      flagLikePositionals: true
    )
    if parsed.help {
      print(help)
      return
    }

    let title = parsed.positionals.joined(separator: " ")
    if title.isEmpty {
      throw GhosttyError.message("set-title requires a title")
    }

    let terminals = try context.client.listTerminals()
    let policy: SurfaceResolutionPolicy = .regularTarget
    let targetTerminal = try resolveSurfaceTarget(
      parsed.target, terminals: terminals, policy: policy)
    let titleResult = TerminalTitlePolicy(client: context.client).setTitle(
      terminalId: targetTerminal.id,
      title: title
    )

    switch titleResult {
    case .endpointSuccess, .fallbackSuccess:
      if parsed.json {
        var output: [String: Any] = [
          "success": true,
          "title_result": titleResult.resultName,
        ]
        if let titleWarning = titleResult.warningMessage {
          output["title_warning"] = titleWarning
        }
        writeJSON(output)
      } else if let titleWarning = titleResult.warningMessage {
        fputs("warning: \(titleWarning)\n", stderr)
      }
      return

    case .invalid(let message), .failure(let message):
      throw GhosttyError.message(message)
    }
  }
}
