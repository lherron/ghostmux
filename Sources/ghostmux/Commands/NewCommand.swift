import Foundation
import GhosttyLib

struct NewCommand: GhostmuxCommand {
  static let name = "new"
  static let aliases = ["new-surface"]
  static let help = """
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
    """

  static func run(context: CommandContext) throws {
    var location: String?
    var workingDirectory: String?
    var title: String?
    var command: String?
    var env: [String: String] = [:]
    var parent: String?
    var json = false
    var focus = false

    var i = 0
    while i < context.args.count {
      let arg = context.args[i]

      if arg == "--window" {
        location = "window"
        i += 1
        continue
      }

      if arg == "--tab" {
        location = "tab"
        i += 1
        continue
      }

      if arg == "--focus" {
        focus = true
        i += 1
        continue
      }

      if arg == "--cwd", i + 1 < context.args.count {
        workingDirectory = context.args[i + 1]
        i += 2
        continue
      }

      if arg == "--title", i + 1 < context.args.count {
        title = context.args[i + 1]
        i += 2
        continue
      }

      if arg == "--command", i + 1 < context.args.count {
        command = context.args[i + 1]
        i += 2
        continue
      }

      if arg == "--env", i + 1 < context.args.count {
        let pair = context.args[i + 1]
        guard let eqIndex = pair.firstIndex(of: "=") else {
          throw GhosttyError.message("env must be in KEY=VALUE form")
        }
        let key = String(pair[..<eqIndex])
        let value = String(pair[pair.index(after: eqIndex)...])
        if key.isEmpty {
          throw GhosttyError.message("env key must be non-empty")
        }
        env[key] = value
        i += 2
        continue
      }

      if arg == "--parent", i + 1 < context.args.count {
        parent = context.args[i + 1]
        i += 2
        continue
      }

      if arg == "--json" {
        json = true
        i += 1
        continue
      }

      if arg == "-h" || arg == "--help" {
        print(help)
        return
      }

      throw GhosttyError.message("unexpected argument: \(arg)")
    }

    let request = CreateTerminalRequest(
      location: location,
      workingDirectory: workingDirectory,
      command: command,
      env: env.isEmpty ? nil : env,
      parent: parent,
      focus: focus
    )

    let terminal = try context.client.createTerminal(request: request)

    let titleResult =
      title.map {
        TerminalTitlePolicy(client: context.client).setTitle(
          terminalId: terminal.id,
          title: $0,
          postCreateDelay: 1.0
        )
      }

    if json {
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
