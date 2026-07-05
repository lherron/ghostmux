import Foundation
import GhosttyLib

struct SendKeysCommand: GhostmuxCommand {
  static let name = "send-keys"
  static let aliases: [String] = []
  static let help = """
    Usage:
      ghostmux send-keys -t <target> [options] <keys>...

    Options:
      -t <target>           Target terminal (UUID, title, or UUID prefix)
                            Falls back to $GHOSTTY_SURFACE_UUID if not specified
      -l, --literal         Send keys literally (no special handling)
      --no-enter            Don't send Enter after keys
      --json                Output JSON
      -h, --help            Show this help

    Sends text/keys followed by Enter by default. Use --no-enter or send-key (singular) to skip Enter.

    Text is sent using the native paste mechanism for reliability.
    Special keys (Enter, Tab, Escape, C-c, etc.) are sent as key events.
    """

  static func run(context: CommandContext) throws {
    var target: String?
    var literal = false
    var noEnter = false
    var json = false
    var positional: [String] = []

    var i = 0
    while i < context.args.count {
      let arg = context.args[i]
      if arg == "-t", i + 1 < context.args.count {
        target = context.args[i + 1]
        i += 2
        continue
      }

      if arg == "-l" || arg == "--literal" {
        literal = true
        i += 1
        continue
      }

      if arg == "--no-enter" {
        noEnter = true
        i += 1
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

      positional.append(arg)
      i += 1
    }

    if positional.isEmpty {
      throw GhosttyError.message("send-keys requires keys to send")
    }

    let terminals = try context.client.listTerminals()
    let policy: SurfaceResolutionPolicy = .regularTarget
    let targetTerminal = try resolveSurfaceTarget(target, terminals: terminals, policy: policy)

    let inputPolicy = InputPlanPolicy(
      literal: literal,
      textGrouping: .joined(separator: " "),
      recognizeSpecialTokens: !literal,
      appendEnter: !noEnter,
      appendEnterDelayMicros: 200_000
    )
    let operations = try InputPlanner.plan(tokens: positional, policy: inputPolicy)
    // executeInputPlan sends planned .text chunks through /input and .key events through /key.
    try executeInputPlan(
      operations,
      to: targetTerminal.id,
      client: context.client,
      policy: inputPolicy
    )

    if json {
      writeJSON(["success": true])
    }
  }
}
