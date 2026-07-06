import Foundation
import GhosttyLib

struct SendKeyCommand: GhostmuxCommand {
  static let name = "send-key"
  static let aliases: [String] = []
  static let help = """
    Usage:
      ghostmux send-key -t <target> [options] <key>

    Options:
      -t <target>           Target terminal (UUID, title, or UUID prefix)
                            Falls back to $GHOSTTY_SURFACE_UUID if not specified
      -l, --literal         Send text literally (no special key handling)
      --json                Output JSON
      -h, --help            Show this help

    Send a key or text without pressing Enter afterward.
    Use send-keys (plural) if you want Enter sent automatically.

    Examples:
      ghostmux send-key -t 1a2b C-c          # Send Ctrl+C
      ghostmux send-key -t 1a2b Escape       # Send Escape
      ghostmux send-key -t 1a2b Tab          # Send Tab
      ghostmux send-key -t 1a2b "partial"    # Type text without Enter
    """

  static func run(context: CommandContext) throws {
    var target: String?
    var literal = false
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
      throw GhosttyError.message("send-key requires a key to send")
    }

    let terminals = try context.client.listTerminals()
    let policy: SurfaceResolutionPolicy = .regularTarget
    let targetTerminal = try resolveSurfaceTarget(target, terminals: terminals, policy: policy)

    let inputPolicy = InputPlanPolicy(
      literal: literal,
      textGrouping: literal ? .joined(separator: " ") : .individualTokens,
      recognizeSpecialTokens: !literal,
      appendEnter: false,
      appendEnterDelayMicros: nil
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
