import Foundation
import GhosttyLib

struct GetPaneSizeCommand: GhostmuxCommand {
    static let name = "get-pane-size"
    static let aliases = ["pane-size", "size"]
    static let help = """
    Usage:
      ghostmux get-pane-size [options]

    Options:
      -t <target>   Target terminal (UUID, title, or prefix)
                    Falls back to $GHOSTTY_SURFACE_UUID if not specified
      --json        Output JSON with all size fields
      -h, --help    Show this help

    Output:
      Without --json: <columns>x<rows> (e.g., "120x40")
      With --json: {"columns": N, "rows": N, "cell_width": N, "cell_height": N}

    Examples:
      ghostmux get-pane-size                    # Size of focused pane
      ghostmux get-pane-size -t 550e8400        # Size of specific pane
      ghostmux get-pane-size --json             # Full size info as JSON
    """

    static func run(context: CommandContext) throws {
        var target: String?
        var json = false

        var i = 0
        while i < context.args.count {
            let arg = context.args[i]

            if arg == "-t", i + 1 < context.args.count {
                target = context.args[i + 1]
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

        // Resolve target
        let resolvedTarget: String
        if let target {
            resolvedTarget = target
        } else if let envTarget = ProcessInfo.processInfo.environment["GHOSTTY_SURFACE_UUID"] {
            resolvedTarget = envTarget
        } else {
            throw GhosttyError.message("get-pane-size requires -t <target> or $GHOSTTY_SURFACE_UUID")
        }

        let terminals = try context.client.listTerminals()
        guard let targetTerminal = resolveTarget(resolvedTarget, terminals: terminals) else {
            throw GhosttyError.message("can't find terminal: \(resolvedTarget)")
        }

        // Get terminal info (already has size from list, but fetch fresh for accuracy)
        let terminal = try context.client.getTerminal(terminalId: targetTerminal.id)

        if json {
            var output: [String: Any] = ["id": terminal.id]
            if let columns = terminal.columns {
                output["columns"] = columns
            }
            if let rows = terminal.rows {
                output["rows"] = rows
            }
            if let cellWidth = terminal.cellWidth {
                output["cell_width"] = cellWidth
            }
            if let cellHeight = terminal.cellHeight {
                output["cell_height"] = cellHeight
            }
            writeJSON(output)
            return
        }

        // Simple output: columns x rows
        let columns = terminal.columns ?? 0
        let rows = terminal.rows ?? 0
        print("\(columns)x\(rows)")
    }
}
