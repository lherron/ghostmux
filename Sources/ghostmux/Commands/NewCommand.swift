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
        --window-id <id>      Create a tab in a managed window (requires --tab)
        --metadata <json>     Initial managed-window metadata (with --window)
        --find-or-create-by <json>
                              Atomically find or create by metadata (with --window)
        --focus               Request focus for the created terminal
        --cwd <path>          Initial working directory
        --title <title>       Set terminal title after creation
        --command <cmd>       Command to run after shell init
        --env <k=v>           Environment variable (repeatable)
        --parent <id>         Parent terminal UUID (for tabs)
        --json                Output JSON
        -h, --help            Show this help

      By default the new terminal is created in the background without stealing
      focus. Pass --focus to request focus for the created window/tab. Focus is
      best-effort; query list-surfaces or the focused endpoint for current state.

      Examples:
        ghostmux new --title 'build: project' --tab --cwd /tmp
        ghostmux new --tab --window-id 550e8400-e29b-41d4-a716-446655440000
        ghostmux new --window --metadata '{"role":"console"}' --json
        ghostmux new --window --metadata '{"role":"console"}' \\
          --find-or-create-by '{"role":"console"}' --json
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
      valueFlags: [
        "--cwd", "--title", "--command", "--env", "--parent", "--window-id", "--metadata",
        "--find-or-create-by",
      ]
    )
    if parsed.help {
      print(help)
      return
    }

    let explicitWindow = parsed.hasFlag("--window")
    let explicitTab = parsed.hasFlag("--tab")
    let parent = parsed.value(for: "--parent")
    let windowId = parsed.value(for: "--window-id")
    let rawMetadata = parsed.value(for: "--metadata")
    let rawFindOrCreateBy = parsed.value(for: "--find-or-create-by")

    if explicitWindow && explicitTab {
      throw GhosttyError.message("new --window and --tab are mutually exclusive")
    }
    if parent != nil && windowId != nil {
      throw GhosttyError.message("new --parent and --window-id are mutually exclusive")
    }
    if windowId != nil && !explicitTab {
      throw GhosttyError.message("new --window-id requires --tab")
    }
    if (rawMetadata != nil || rawFindOrCreateBy != nil) && explicitTab {
      throw GhosttyError.message("new --metadata and --find-or-create-by require --window")
    }
    if (rawMetadata != nil || rawFindOrCreateBy != nil) && parent != nil {
      throw GhosttyError.message("new managed-window creation does not accept --parent")
    }
    if explicitWindow && parent != nil {
      throw GhosttyError.message("new --window does not accept --parent")
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

    if explicitWindow || rawMetadata != nil || rawFindOrCreateBy != nil {
      let metadata = try rawMetadata.map(parseJSONObject)
      let findOrCreateBy = try rawFindOrCreateBy.map(parseJSONObject)
      let request = CreateWindowRequest(
        metadata: metadata,
        findOrCreateBy: findOrCreateBy,
        workingDirectory: parsed.value(for: "--cwd"),
        command: parsed.value(for: "--command"),
        env: env.isEmpty ? nil : env,
        focus: focus
      )
      let result = try context.client.createWindow(request: request)
      let titleResult =
        result.created
        ? parsed.value(for: "--title").flatMap { title in
          result.window.terminalIds.first.map {
            TerminalTitlePolicy(client: context.client).setTitle(
              terminalId: $0,
              title: title,
              postCreateDelay: 1.0
            )
          }
        } : nil

      if parsed.json {
        var output = result.toJsonDict()
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

      let action = result.created ? "Created" : "Found"
      print("\(action) window: \(result.window.id) - \(result.window.title)")
      if let titleWarning = titleResult?.warningMessage {
        fputs("warning: \(titleWarning)\n", stderr)
      }
      if let titleError = titleResult?.errorMessage {
        fputs("warning: \(titleError)\n", stderr)
      }
      return
    }

    let request = CreateTerminalRequest(
      location: location,
      workingDirectory: parsed.value(for: "--cwd"),
      command: parsed.value(for: "--command"),
      env: env.isEmpty ? nil : env,
      parent: parent,
      window: windowId,
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
      output.removeValue(forKey: "focused")
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

    print(terminalSummary(terminal, includeFocusStatus: false))
    if let titleWarning = titleResult?.warningMessage {
      fputs("warning: \(titleWarning)\n", stderr)
    }
    if let titleError = titleResult?.errorMessage {
      fputs("warning: \(titleError)\n", stderr)
    }
  }

  private static func parseJSONObject(_ raw: String) throws -> [String: Any] {
    guard let data = raw.data(using: .utf8) else {
      throw GhosttyError.message("metadata JSON must be valid UTF-8")
    }
    do {
      let object = try JSONSerialization.jsonObject(with: data, options: [])
      guard let dict = object as? [String: Any] else {
        throw GhosttyError.message("metadata JSON must be an object")
      }
      return dict
    } catch let error as GhosttyError {
      throw error
    } catch {
      throw GhosttyError.message("metadata JSON must be a valid JSON object")
    }
  }
}
