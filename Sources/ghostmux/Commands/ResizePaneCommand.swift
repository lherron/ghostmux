import Foundation
import GhosttyLib

struct ResizePaneCommand: GhostmuxCommand {
    static let name = "resize-pane"
    static let aliases = ["resizep"]
    static let help = """
    Usage:
      ghostmux resize-pane [options]

    Options:
      -t <target>           Target terminal (UUID, title, or prefix)
                            Falls back to $GHOSTTY_SURFACE_UUID if not specified
      -d, --direction <dir> Resize direction: left, right, up, down (required)
      -a, --amount <pixels> Amount to resize in pixels (default: 50)
      --json                Output JSON
      -h, --help            Show this help

    Directions:
      left    Shrink pane from left edge (or expand neighbor)
      right   Expand pane from right edge (or shrink neighbor)
      up      Shrink pane from top edge (or expand neighbor)
      down    Expand pane from bottom edge (or shrink neighbor)

    Examples:
      ghostmux resize-pane -d right -a 100     # Expand right by 100px
      ghostmux resize-pane -d up -a 50         # Shrink from top by 50px
      ghostmux resize-pane -t 550e8400 -d down # Expand down by default 50px
    """

    static func run(context: CommandContext) throws {
        var target: String?
        var direction: String?
        var amount: Int = 50
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

            if (arg == "-a" || arg == "--amount"), i + 1 < context.args.count {
                guard let parsed = Int(context.args[i + 1]), parsed > 0 else {
                    throw GhosttyError.message("amount must be a positive integer")
                }
                amount = parsed
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

        // Validate direction
        guard let direction else {
            throw GhosttyError.message("resize-pane requires -d <direction>")
        }

        let validDirections = ["left", "right", "up", "down"]
        guard validDirections.contains(direction) else {
            throw GhosttyError.message("invalid direction '\(direction)': must be left, right, up, or down")
        }

        // Resolve target
        let resolvedTarget: String
        if let target {
            resolvedTarget = target
        } else if let envTarget = ProcessInfo.processInfo.environment["GHOSTTY_SURFACE_UUID"] {
            resolvedTarget = envTarget
        } else {
            throw GhosttyError.message("resize-pane requires -t <target> or $GHOSTTY_SURFACE_UUID")
        }

        let terminals = try context.client.listTerminals()
        guard let targetTerminal = resolveTarget(resolvedTarget, terminals: terminals) else {
            throw GhosttyError.message("can't find terminal: \(resolvedTarget)")
        }

        // Execute resize action
        let action = "resize_split:\(direction),\(amount)"
        try context.client.executeAction(terminalId: targetTerminal.id, action: action)

        if json {
            writeJSON(["success": true, "direction": direction, "amount": amount])
            return
        }

        print("resized \(direction) by \(amount)px")
    }
}
