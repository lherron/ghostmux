import Foundation
import GhosttyLib

struct StatusBarCommand: GhostmuxCommand {
  static let name = "statusbar"
  static let aliases: [String] = []
  static let help = commandHelp(
    """
      Usage:
        ghostmux statusbar set -t <target> "left|center|right" [--fg <color>] [--bg <color>]
        ghostmux statusbar set -t <target> --fg <color> --bg <color>
        ghostmux statusbar get -t <target> [--json]
        ghostmux statusbar show -t <target>
        ghostmux statusbar hide -t <target>
        ghostmux statusbar toggle -t <target>

        Note: "show" makes the bar visible; "get" reads back the configured spec
        (left/center/right text, fg, bg, visible state).

        Use empty fields for blanks, e.g. "left||right"

      Options:
        -t <target>           Target terminal (UUID, title, or UUID prefix)
                              Falls back to $GHOSTTY_SURFACE_UUID if not specified
        --window              Apply to window fallback instead of surface
        --fg <color>          Foreground (text) color
        --bg <color>          Background color
        --json                Output JSON
        -h, --help            Show this help

      Colors:
        Named colors: black, red, green, yellow, blue, magenta, cyan, white,
                      brightblack, brightred, brightgreen, brightyellow,
                      brightblue, brightmagenta, brightcyan, brightwhite,
                      orange, pink, purple, teal, navy, maroon, gray, silver
        Hex values:   #RGB, #RRGGBB, or without # prefix
        Special:      "default" resets to default color
    """)

  static func run(context: CommandContext) throws {
    let parsed = try parseCommandArguments(
      context.args,
      positionals: .collect,
      booleanFlags: ["--window"],
      valueFlags: ["--fg", "--bg"],
      flagLikePositionals: true
    )
    if parsed.help {
      print(help)
      return
    }

    guard let subcommand = parsed.positionals.first else {
      throw GhosttyError.message("statusbar requires a subcommand: set, show, hide, or toggle")
    }

    let terminals = try context.client.listTerminals()
    let policy: SurfaceResolutionPolicy = .regularTarget
    let targetTerminal = try resolveSurfaceTarget(
      parsed.target, terminals: terminals, policy: policy)

    let fgColor = parsed.value(for: "--fg")
    let bgColor = parsed.value(for: "--bg")
    let windowScope = parsed.hasFlag("--window")
    let scope = windowScope ? "window" : nil

    switch subcommand {
    case "set":
      let rawValue = parsed.positionals.dropFirst().joined(separator: " ")

      // Allow set with just colors (no text content)
      if rawValue.isEmpty && fgColor == nil && bgColor == nil {
        throw GhosttyError.message(
          "statusbar set requires \"left|center|right\" or --fg/--bg colors")
      }

      var left: String?
      var center: String?
      var right: String?

      if !rawValue.isEmpty {
        let parts = rawValue.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count == 3 else {
          throw GhosttyError.message(
            "statusbar set requires exactly three fields: left|center|right")
        }
        left = String(parts[0])
        center = String(parts[1])
        right = String(parts[2])
      }

      try context.client.setStatusBar(
        terminalId: targetTerminal.id,
        left: left,
        center: center,
        right: right,
        visible: true,
        scope: scope,
        fg: fgColor,
        bg: bgColor
      )
    case "get":
      if parsed.positionals.count > 1 {
        throw GhosttyError.message("statusbar get does not take extra arguments")
      }
      let info = try context.client.getStatusBar(terminalId: targetTerminal.id, scope: scope)
      if parsed.json {
        writeJSON(info.toJsonDict())
      } else {
        print("left:    \(info.left)")
        print("center:  \(info.center)")
        print("right:   \(info.right)")
        print("visible: \(info.visible)")
        print("fg:      \(info.fg ?? "default")")
        print("bg:      \(info.bg ?? "default")")
        print("scope:   \(info.scope)")
      }
      return
    case "show":
      if parsed.positionals.count > 1 {
        throw GhosttyError.message("statusbar show does not take extra arguments")
      }
      try context.client.setStatusBar(terminalId: targetTerminal.id, visible: true, scope: scope)
    case "hide":
      if parsed.positionals.count > 1 {
        throw GhosttyError.message("statusbar hide does not take extra arguments")
      }
      try context.client.setStatusBar(terminalId: targetTerminal.id, visible: false, scope: scope)
    case "toggle":
      if parsed.positionals.count > 1 {
        throw GhosttyError.message("statusbar toggle does not take extra arguments")
      }
      try context.client.setStatusBar(terminalId: targetTerminal.id, toggle: true, scope: scope)
    default:
      throw GhosttyError.message("unknown statusbar subcommand: \(subcommand)")
    }

    if parsed.json {
      writeJSON(["success": true])
    }
  }
}
