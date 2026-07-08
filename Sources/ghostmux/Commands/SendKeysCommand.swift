import Foundation
import GhosttyLib

struct SendKeysCommand: GhostmuxCommand {
  static let name = "send-keys"
  static let aliases: [String] = []
  static let help = commandHelp(
    """
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
    """)

  static func run(context: CommandContext) throws {
    let parsed = try parseCommandArguments(
      context.args,
      positionals: .collect,
      booleanFlags: ["-l", "--literal", "--no-enter"],
      flagLikePositionals: true
    )
    if parsed.help {
      print(help)
      return
    }

    if parsed.positionals.isEmpty {
      throw GhosttyError.message("send-keys requires keys to send")
    }

    let terminals = try context.client.listTerminals()
    let policy: SurfaceResolutionPolicy = .regularTarget
    let targetTerminal = try resolveSurfaceTarget(
      parsed.target, terminals: terminals, policy: policy)

    let literal = parsed.hasFlag("-l") || parsed.hasFlag("--literal")
    let noEnter = parsed.hasFlag("--no-enter")
    let inputPolicy = InputPlanPolicy(
      literal: literal,
      textGrouping: .joined(separator: " "),
      recognizeSpecialTokens: !literal,
      appendEnter: !noEnter,
      appendEnterDelayMicros: 200_000
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
