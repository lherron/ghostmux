import Foundation
import GhosttyLib

struct NewCommand: GhostmuxCommand {
  static let name = "new"
  static let aliases = ["new-surface"]
  static let help = commandHelp(
    """
      Usage:
        ghostmux new [options]

      Options:
        --window              Create a new window (default)
        --tab                 Create a new tab
        --focus               Focus the created terminal (default: do not focus)
        --cwd <path>          Initial working directory
        --title <title>       Set terminal title after creation
        --command <cmd>       Command to run after shell init
        --env <k=v>           Environment variable (repeatable)
        --parent <id>         Parent terminal UUID (for tabs)
        --json                Output JSON
        -h, --help            Show this help

      By default the new terminal is created in the background without stealing
      focus. Pass --focus to move focus to the created window/tab.

      Examples:
        ghostmux new --title 'build: project' --tab --cwd /tmp
        ghostmux new --focus
    """)

  static func run(context: CommandContext) throws {
    var location: String?
    var env: [String: String] = [:]
    var focus = false

    let parsed = try parseCommandArguments(
      context.args,
      targetAliases: [],
      booleanFlags: ["--window", "--tab", "--focus"],
      valueFlags: ["--cwd", "--title", "--command", "--env", "--parent"]
    )
    if parsed.help {
      print(help)
      return
    }

    for flag in parsed.flagOrder {
      switch flag {
      case "--window":
        location = "window"
      case "--tab":
        location = "tab"
      case "--focus":
        focus = true
      default:
        break
      }
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

    let request = CreateTerminalRequest(
      location: location,
      workingDirectory: parsed.value(for: "--cwd"),
      command: parsed.value(for: "--command"),
      env: env.isEmpty ? nil : env,
      parent: parsed.value(for: "--parent"),
      focus: focus
    )

    let terminal = try context.client.createTerminal(request: request)

    let titleResult =
      parsed.value(for: "--title").map {
        TerminalTitlePolicy(client: context.client).setTitle(
          terminalId: terminal.id,
          title: $0,
          postCreateDelay: 1.0
        )
      }

    if parsed.json {
      var output = terminal.toJsonDict()
      if let titleResult {
        output["title_result"] = titleResult.resultName
        if let titleWarning = titleResult.warningMessage {
          output["title_warning"] = titleWarning
        }
        if let titleError = titleResult.errorMessage {
          output["title_error"] = titleError
        }
      }
      writeJSON(output)
      return
    }

    print(terminalSummary(terminal))
    if let titleWarning = titleResult?.warningMessage {
      fputs("warning: \(titleWarning)\n", stderr)
    }
    if let titleError = titleResult?.errorMessage {
      fputs("warning: \(titleError)\n", stderr)
    }
  }
}
