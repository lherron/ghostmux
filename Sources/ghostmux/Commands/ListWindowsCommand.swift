import Foundation
import GhosttyLib

struct ListWindowsCommand: GhostmuxCommand {
  static let name = "list-windows"
  static let aliases: [String] = []
  static let help = commandHelp(
    """
      Usage:
        ghostmux list-windows [--meta <key=value>]... [--json]

      Options:
        --meta <key=value>    Filter by managed-window metadata (repeatable, AND)
        --json                Output JSON
        -h, --help            Show this help

      JSON literal filter values retain their type; other values are strings.
      Examples: --meta role=console --meta active=true
    """)

  static func run(context: CommandContext) throws {
    let parsed = try parseCommandArguments(
      context.args,
      targetAliases: [],
      valueFlags: ["--meta"]
    )
    if parsed.help {
      print(help)
      return
    }

    var filters: [String: String] = [:]
    for pair in parsed.values(for: "--meta") {
      guard let eqIndex = pair.firstIndex(of: "=") else {
        throw GhosttyError.message("metadata filter must be in KEY=VALUE form")
      }
      let key = String(pair[..<eqIndex])
      let value = String(pair[pair.index(after: eqIndex)...])
      guard !key.isEmpty else {
        throw GhosttyError.message("metadata filter key must be non-empty")
      }
      filters[key] = value
    }

    let windows = try context.client.listWindows(metadataFilters: filters)
    if parsed.json {
      writeJSON(["windows": windows.map { $0.toJsonDict() }])
      return
    }
    if windows.isEmpty {
      print("(no windows)")
      return
    }
    for window in windows {
      let focus = window.focused ? " - focused" : ""
      print("Window: \(window.id) - \(window.title)\(focus)")
      print("  terminals: \(window.terminalIds.joined(separator: ", "))")
      if !window.metadata.isEmpty {
        let data = try JSONSerialization.data(
          withJSONObject: window.metadata,
          options: [.sortedKeys]
        )
        if let text = String(data: data, encoding: .utf8) {
          print("  metadata: \(text)")
        }
      }
    }
  }
}
