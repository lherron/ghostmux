import Foundation
import GhosttyLib

struct SetTitleCommand: GhostmuxCommand {
  static let name = "set-title"
  static let aliases: [String] = []
  static let help = """
    Usage:
      ghostmux set-title -t <target> <title>

    Options:
      -t <target>           Target terminal (UUID, title, or UUID prefix)
                            Falls back to $GHOSTTY_SURFACE_UUID if not specified
      --json                Output JSON
      -h, --help            Show this help
    """

  static func run(context: CommandContext) throws {
    var target: String?
    var positional: [String] = []
    var json = false

    var i = 0
    while i < context.args.count {
      let arg = context.args[i]
      if arg == "-t", i + 1 < context.args.count {
        target = context.args[i + 1]
        i += 2
        continue
      }

      if arg == "-h" || arg == "--help" {
        print(help)
        return
      }

      if arg == "--json" {
        json = true
        i += 1
        continue
      }

      positional.append(arg)
      i += 1
    }

    let title = positional.joined(separator: " ")
    if title.isEmpty {
      throw GhosttyError.message("set-title requires a title")
    }

    let terminals = try context.client.listTerminals()
    let policy: SurfaceResolutionPolicy = .regularTarget
    let targetTerminal = try resolveSurfaceTarget(target, terminals: terminals, policy: policy)
    let titleResult = TerminalTitlePolicy(client: context.client).setTitle(
      terminalId: targetTerminal.id,
      title: title
    )

    switch titleResult {
    case .endpointSuccess, .fallbackSuccess:
      if json {
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
