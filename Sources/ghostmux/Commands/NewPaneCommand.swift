import Foundation

struct NewPaneCommand: GhostmuxCommand {
    static let name = "new-pane"
    static let aliases = ["splitp", "split-pane"]
    static let help = """
    Usage:
      ghostmux new-pane [options]

    Options:
      -t <target>           Target terminal to split (UUID, title, or prefix)
                            Falls back to $GHOSTTY_SURFACE_UUID if not specified
      -d, --direction <dir> Split direction: left, right, up, down (default: right)
      --cwd <path>          Initial working directory for new pane
      --command <cmd>       Command to run after shell init
      --env <k=v>           Environment variable (repeatable)
      --json                Output JSON
      -h, --help            Show this help

    Directions:
      left    Split horizontally, new pane on the left
      right   Split horizontally, new pane on the right (default)
      up      Split vertically, new pane above
      down    Split vertically, new pane below

    Examples:
      ghostmux new-pane                           # Split right from focused pane
      ghostmux new-pane -d down                   # Split down from focused pane
      ghostmux new-pane -t 550e8400 -d left       # Split left from specific pane
      ghostmux new-pane -d down --cwd /tmp        # Split down with working directory
    """

    static func run(context: CommandContext) throws {
        var target: String?
        var direction = "right"
        var workingDirectory: String?
        var command: String?
        var env: [String: String] = [:]
        var json = false

        var i = 0
        while i < context.args.count {
            let arg = context.args[i]

            if arg == "-t", i + 1 < context.args.count {
                target = context.args[i + 1]
                i += 2
                continue
            }

            if (arg == "-d" || arg == "--direction"), i + 1 < context.args.count {
                direction = context.args[i + 1].lowercased()
                i += 2
                continue
            }

            if arg == "--cwd", i + 1 < context.args.count {
                workingDirectory = context.args[i + 1]
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
                    throw GhostmuxError.message("env must be in KEY=VALUE form")
                }
                let key = String(pair[..<eqIndex])
                let value = String(pair[pair.index(after: eqIndex)...])
                if key.isEmpty {
                    throw GhostmuxError.message("env key must be non-empty")
                }
                env[key] = value
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

            throw GhostmuxError.message("unexpected argument: \(arg)")
        }

        // Validate direction
        let validDirections = ["left", "right", "up", "down"]
        guard validDirections.contains(direction) else {
            throw GhostmuxError.message("invalid direction '\(direction)': must be left, right, up, or down")
        }

        // Resolve target
        let resolvedTarget: String
        if let target {
            resolvedTarget = target
        } else if let envTarget = ProcessInfo.processInfo.environment["GHOSTTY_SURFACE_UUID"] {
            resolvedTarget = envTarget
        } else {
            // No target specified - API will use focused terminal
            resolvedTarget = ""
        }

        // Find parent terminal if target specified
        var parentId: String?
        if !resolvedTarget.isEmpty {
            let terminals = try context.client.listTerminals()
            guard let targetTerminal = resolveTarget(resolvedTarget, terminals: terminals) else {
                throw GhostmuxError.message("can't find terminal: \(resolvedTarget)")
            }
            parentId = targetTerminal.id
        }

        // Create the split
        let location = "split:\(direction)"
        let request = CreateTerminalRequest(
            location: location,
            workingDirectory: workingDirectory,
            command: command,
            env: env.isEmpty ? nil : env,
            parent: parentId
        )

        let terminal = try context.client.createTerminal(request: request)

        if json {
            writeJSON(terminal.toJsonDict())
            return
        }

        print(terminalSummary(terminal))
    }
}
