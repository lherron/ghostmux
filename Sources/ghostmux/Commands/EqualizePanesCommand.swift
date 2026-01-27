import Foundation
import GhosttyLib

struct EqualizePanesCommand: GhostmuxCommand {
    static let name = "equalize-panes"
    static let aliases = ["equalize", "eq"]
    static let help = """
    Usage:
      ghostmux equalize-panes [options]

    Options:
      -t <target>   Target terminal (UUID, title, or prefix)
                    Falls back to $GHOSTTY_SURFACE_UUID if not specified
      --json        Output JSON
      -h, --help    Show this help

    Description:
      Makes all panes in the current window equal size by adjusting split ratios
      based on the number of panes in each split direction.

    Examples:
      ghostmux equalize-panes                  # Equalize from focused pane
      ghostmux equalize-panes -t 550e8400      # Equalize from specific pane
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
            throw GhosttyError.message("equalize-panes requires -t <target> or $GHOSTTY_SURFACE_UUID")
        }

        let terminals = try context.client.listTerminals()
        guard let targetTerminal = resolveTarget(resolvedTarget, terminals: terminals) else {
            throw GhosttyError.message("can't find terminal: \(resolvedTarget)")
        }

        // Execute equalize action
        try context.client.executeAction(terminalId: targetTerminal.id, action: "equalize_splits")

        if json {
            writeJSON(["success": true])
            return
        }

        print("panes equalized")
    }
}
