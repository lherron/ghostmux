import Foundation
import GhosttyLib

struct FocusCommand: GhostmuxCommand {
  static let name = "focus"
  static let aliases: [String] = []
  static let help = """
    Usage:
      ghostmux focus -t <target> [options]

    Raise the target terminal's window to the foreground.

    Options:
      -t <target>           Target terminal (UUID, title, or UUID prefix)
                            Falls back to $GHOSTTY_SURFACE_UUID if not specified
      --json                Output JSON
      -h, --help            Show this help
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

    let terminals = try context.client.listTerminals()
    let policy: SurfaceResolutionPolicy = .regularTarget
    let targetTerminal = try resolveSurfaceTarget(target, terminals: terminals, policy: policy)

    try context.client.focusTerminal(terminalId: targetTerminal.id)
    if json {
      writeJSON(["success": true])
    }
  }
}
