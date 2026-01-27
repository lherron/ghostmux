import Foundation
import GhosttyLib

struct ListSessionsCommand: GhostmuxCommand {
    static let name = "list-surfaces"
    static let aliases = ["list-sessions", "ls"]
    static let help = """
    Usage:
      ghostmux list-surfaces

    Options:
      --json                Output JSON

    List all terminals.
    """

    static func run(context: CommandContext) throws {
        var json = false
        for arg in context.args {
            if arg == "-h" || arg == "--help" {
                print(help)
                return
            }
            if arg == "--json" {
                json = true
                continue
            }
            throw GhosttyError.message("unexpected argument: \(arg)")
        }

        let terminals = try context.client.listTerminals()
        if json {
            let payload = ["terminals": terminals.map { $0.toJsonDict() }]
            writeJSON(payload)
            return
        }
        if terminals.isEmpty {
            print("(no terminals)")
            return
        }
        for terminal in terminals {
            print(terminalSummary(terminal))
        }
    }
}
