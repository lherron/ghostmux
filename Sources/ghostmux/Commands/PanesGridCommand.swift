import Foundation

struct PanesGridCommand: GhostmuxCommand {
    static let name = "panes-grid"
    static let aliases = ["grid"]
    static let help = """
    Usage:
      ghostmux panes-grid <columns>x<rows> [options]

    Options:
      -t, --target <id>   Target terminal to start from (UUID, title, or prefix)
                          Falls back to $GHOSTTY_SURFACE_UUID if not specified
      --cwd <path>  Initial working directory for all new panes
      --json        Output JSON with all pane IDs
      -h, --help    Show this help

    Arguments:
      <columns>x<rows>  Grid dimensions (e.g., 3x2 for 3 columns, 2 rows = 6 panes)

    Examples:
      ghostmux panes-grid 2x2                  # Create 2x2 grid (4 panes)
      ghostmux panes-grid 3x2                  # Create 3x2 grid (6 panes)
      ghostmux panes-grid 4x1                  # Create 4 horizontal panes
      ghostmux panes-grid 1x3                  # Create 3 vertical panes
      ghostmux panes-grid 3x2 --cwd /tmp       # Grid with working directory
    """

    static func run(context: CommandContext) throws {
        var target: String?
        var gridSpec: String?
        var workingDirectory: String?
        var json = false

        var i = 0
        while i < context.args.count {
            let arg = context.args[i]

            if (arg == "-t" || arg == "--target"), i + 1 < context.args.count {
                target = context.args[i + 1]
                i += 2
                continue
            }

            if arg == "--cwd", i + 1 < context.args.count {
                workingDirectory = context.args[i + 1]
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

            if arg.hasPrefix("-") {
                throw GhostmuxError.message("unexpected argument: \(arg)")
            }

            // Positional argument - should be grid spec
            if gridSpec == nil {
                gridSpec = arg
                i += 1
                continue
            }

            throw GhostmuxError.message("unexpected argument: \(arg)")
        }

        // Parse grid spec
        guard let gridSpec else {
            throw GhostmuxError.message("panes-grid requires grid size (e.g., 3x2)")
        }

        let parts = gridSpec.lowercased().split(separator: "x")
        guard parts.count == 2,
              let columns = Int(parts[0]), columns >= 1,
              let rows = Int(parts[1]), rows >= 1 else {
            throw GhostmuxError.message("invalid grid format '\(gridSpec)': use <columns>x<rows> (e.g., 3x2)")
        }

        if columns > 10 || rows > 10 {
            throw GhostmuxError.message("grid too large: maximum 10x10")
        }

        // Resolve starting terminal
        let startingId: String
        if let target {
            let terminals = try context.client.listTerminals()
            guard let targetTerminal = resolveTarget(target, terminals: terminals) else {
                throw GhostmuxError.message("can't find terminal: \(target)")
            }
            startingId = targetTerminal.id
        } else if let envTarget = ProcessInfo.processInfo.environment["GHOSTTY_SURFACE_UUID"] {
            startingId = envTarget
        } else {
            // Use focused terminal
            let terminals = try context.client.listTerminals()
            guard let focused = terminals.first(where: { $0.focused }) else {
                throw GhostmuxError.message("no focused terminal found")
            }
            startingId = focused.id
        }

        // Build the grid
        // Strategy: Create rows first (vertical splits), then columns in each row (horizontal splits)
        // This creates a more balanced tree structure

        var allPanes: [[String]] = []  // [row][column] = pane ID

        // Create additional rows by splitting down from the first pane
        // We need (rows - 1) vertical splits to create `rows` rows
        var rowStarters = [startingId]  // First pane of each row

        for _ in 1..<rows {
            let request = CreateTerminalRequest(
                location: "split:down",
                workingDirectory: workingDirectory,
                command: nil,
                env: nil,
                parent: rowStarters.last
            )
            let newPane = try context.client.createTerminal(request: request)
            rowStarters.append(newPane.id)
        }

        // Now for each row starter, create the columns by splitting right
        for rowStarterId in rowStarters {
            var rowPanes = [rowStarterId]

            // Create (columns - 1) horizontal splits to create `columns` columns
            for _ in 1..<columns {
                let request = CreateTerminalRequest(
                    location: "split:right",
                    workingDirectory: workingDirectory,
                    command: nil,
                    env: nil,
                    parent: rowPanes.last
                )
                let newPane = try context.client.createTerminal(request: request)
                rowPanes.append(newPane.id)
            }

            allPanes.append(rowPanes)
        }

        // Equalize all panes
        try context.client.executeAction(terminalId: startingId, action: "equalize_splits")

        // Focus back to the original pane
        try context.client.focusTerminal(terminalId: startingId)

        // Output results
        let totalPanes = columns * rows

        if json {
            let output: [String: Any] = [
                "columns": columns,
                "rows": rows,
                "total_panes": totalPanes,
                "panes": allPanes
            ]
            writeJSON(output)
            return
        }

        print("created \(columns)x\(rows) grid (\(totalPanes) panes)")
        for (rowIndex, row) in allPanes.enumerated() {
            let shortIds = row.map { String($0.prefix(8)) }
            print("  row \(rowIndex + 1): \(shortIds.joined(separator: " | "))")
        }
    }
}
