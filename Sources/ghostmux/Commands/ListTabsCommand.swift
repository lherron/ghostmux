import Foundation
import GhosttyLib

struct ListTabsCommand: GhostmuxCommand {
  static let name = "list-tabs"
  static let aliases: [String] = []
  static let help = commandHelp(
    """
      Usage:
        ghostmux list-tabs [-t <surface> | --window-id <id>] [--json]

      Options:
        -t <surface>          List panes sharing the target surface's native tab
                              Falls back to $GHOSTTY_SURFACE_UUID if omitted
        --window-id <id>      List panes across every tab in a managed window
        --json                Output JSON terminal rows
        -h, --help            Show this help

      Rows contain id, short_id, title, and focused.
    """)

  static func run(context: CommandContext) throws {
    let parsed = try parseCommandArguments(
      context.args,
      targetAliases: ["-t"],
      valueFlags: ["--window-id"]
    )
    if parsed.help {
      print(help)
      return
    }

    let windowId = parsed.value(for: "--window-id")
    if parsed.target != nil, windowId != nil {
      throw GhosttyError.message("list-tabs -t and --window-id are mutually exclusive")
    }

    let terminals = try context.client.listTerminals()
    let selectedTerminals: [Terminal]
    if let windowId {
      let window = try context.client.getWindow(windowId: windowId)
      guard !window.tabs.isEmpty else {
        throw GhosttyError.message(
          "server did not return tab grouping; update ScriptableGhostty")
      }
      selectedTerminals = terminalsInWireOrder(
        ids: window.tabs.flatMap(\.terminalIds),
        terminals: terminals
      )
    } else {
      let target = try resolveSurfaceTarget(
        parsed.target,
        terminals: terminals,
        policy: .regularTarget
      )
      guard let tabId = target.tabId else {
        throw GhosttyError.message(
          "target terminal has no tab identity; update ScriptableGhostty or choose a normal terminal"
        )
      }
      guard let windowId = target.windowId else {
        throw GhosttyError.message("target terminal has no managed window identity")
      }
      let window = try context.client.getWindow(windowId: windowId)
      guard let tab = window.tabs.first(where: { $0.id == tabId }) else {
        throw GhosttyError.message("target tab is not present in its managed window")
      }
      selectedTerminals = terminalsInWireOrder(ids: tab.terminalIds, terminals: terminals)
    }

    if parsed.json {
      writeJSON(["terminals": selectedTerminals.map(terminalRow)])
      return
    }
    if selectedTerminals.isEmpty {
      print("(no terminals)")
      return
    }
    for terminal in selectedTerminals {
      let focused = terminal.focused ? "true" : "false"
      print(
        "\(terminal.id)\t\(NameGenerator.shortUUID(terminal.id))\t\(terminal.title)\t\(focused)"
      )
    }
  }

  private static func terminalsInWireOrder(
    ids: [String],
    terminals: [Terminal]
  ) -> [Terminal] {
    let byId = Dictionary(uniqueKeysWithValues: terminals.map { ($0.id, $0) })
    return ids.compactMap { byId[$0] }
  }

  private static func terminalRow(_ terminal: Terminal) -> [String: Any] {
    [
      "id": terminal.id,
      "short_id": NameGenerator.shortUUID(terminal.id),
      "title": terminal.title,
      "focused": terminal.focused,
    ]
  }
}
