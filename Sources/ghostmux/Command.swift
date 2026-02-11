import Foundation
import GhosttyLib

struct CommandContext {
    let args: [String]
    let client: GhosttyClient
}

protocol GhostmuxCommand {
    static var name: String { get }
    static var aliases: [String] { get }
    static var help: String { get }
    static func run(context: CommandContext) throws
}

func terminalSummary(_ terminal: Terminal) -> String {
    let name = NameGenerator.nameFromUUID(terminal.id)
    let shortId = String(terminal.id.prefix(8))

    var output = "Created pane: \(name) (\(shortId))"

    if terminal.focused {
        output += " - now focused"
    }

    if let cwd = terminal.workingDirectory {
        output += "\nWorking directory: \(cwd)"
    }

    if let columns = terminal.columns, let rows = terminal.rows {
        output += "\nSize: \(columns)x\(rows)"
    }

    return output
}
