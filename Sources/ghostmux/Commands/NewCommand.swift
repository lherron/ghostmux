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
      --cwd <path>          Initial working directory
      --title <title>       Set terminal title after creation
      --command <cmd>       Command to run after shell init
      --env <k=v>           Environment variable (repeatable)
      --parent <id>         Parent terminal UUID (for tabs)
      --json                Output JSON
      -h, --help            Show this help

    Examples:
      ghostmux new --title 'build: project' --tab --cwd /tmp
    """

    static func run(context: CommandContext) throws {
        var location: String?
        var workingDirectory: String?
        var title: String?
        var command: String?
        var env: [String: String] = [:]
        var parent: String?
        var json = false

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
            parent: parent
        )

        let terminal = try context.client.createTerminal(request: request)

        // Set title if provided (with delay to let shell initialize first)
        var titleError: String?
        if let title {
            if title.contains("\u{1b}") || title.contains("\u{07}") {
                titleError = "title contains invalid characters (escape or bell)"
            } else {
                // Wait for shell to fully initialize before setting title
                // Otherwise the shell may overwrite our title with its default
                usleep(1_000_000)  // 1 second
                do {
                    try context.client.setTitle(terminalId: terminal.id, title: title)
                } catch {
                    titleError = "failed to set title: \(error)"
                }
            }
        }

        if json {
            var output = terminal.toJsonDict()
            if let titleError {
                output["title_error"] = titleError
            }
            writeJSON(output)
            return
        }

        print(terminalSummary(terminal))
        if let titleError {
            fputs("warning: \(titleError)\n", stderr)
        }
    }
}
