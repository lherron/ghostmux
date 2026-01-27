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
    let shortId = String(terminal.id.prefix(8))
    let size = terminal.columns.flatMap { columns in
        terminal.rows.map { rows in "[\(columns)x\(rows)]" }
    }

    var titlePart = terminal.title
    if let cwd = terminal.workingDirectory {
        titlePart += " (\(cwd))"
    }

    var parts: [String] = [shortId, titlePart]
    if let size {
        parts.append(size)
    }
    if terminal.focused {
        parts.append("(focused)")
    }

    return parts.joined(separator: " ")
}
