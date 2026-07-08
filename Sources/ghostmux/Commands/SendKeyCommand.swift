import Foundation
import GhosttyLib

struct SendKeyCommand: GhostmuxCommand {
  static let name = "send-key"
  static let aliases: [String] = []
  static let help = commandHelp(
    """
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
    """)

  static func run(context: CommandContext) throws {
    let parsed = try parseCommandArguments(
      context.args,
      positionals: .collect,
      booleanFlags: ["-l", "--literal"],
      flagLikePositionals: true
    )
    if parsed.help {
      print(help)
      return
    }

    if parsed.positionals.isEmpty {
      throw GhosttyError.message("send-key requires a key to send")
    }

    let terminals = try context.client.listTerminals()
    let policy: SurfaceResolutionPolicy = .regularTarget
    let targetTerminal = try resolveSurfaceTarget(
      parsed.target, terminals: terminals, policy: policy)

    let literal = parsed.hasFlag("-l") || parsed.hasFlag("--literal")
    let inputPolicy = InputPlanPolicy(
      literal: literal,
      textGrouping: literal ? .joined(separator: " ") : .individualTokens,
      recognizeSpecialTokens: !literal,
      appendEnter: false,
      appendEnterDelayMicros: nil
    )
    let operations = try InputPlanner.plan(tokens: parsed.positionals, policy: inputPolicy)
    // executeInputPlan sends planned .text chunks through /input and .key events through /key.
    try executeInputPlan(
      operations,
      to: targetTerminal.id,
      client: context.client,
      policy: inputPolicy
    )

    if parsed.json {
      writeJSON(["success": true])
    }
  }
}
