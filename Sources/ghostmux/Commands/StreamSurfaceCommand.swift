import Foundation
import GhosttyLib

struct StreamSurfaceCommand: GhostmuxCommand {
  static let name = "stream-surface"
  static let aliases = ["stream"]
  static let help = commandHelp(
    """
      Usage:
        ghostmux stream-surface -t <target> [options]

      Stream raw PTY output from a terminal in real-time.

      Options:
        -t <target>           Target terminal (UUID, title, or UUID prefix)
                              Falls back to $GHOSTTY_SURFACE_UUID if not specified
        --raw                 Output raw bytes (default: decode as UTF-8 text)
        -h, --help            Show this help
    """)

  static func run(context: CommandContext) throws {
    let parsed = try parseCommandArguments(
      context.args,
      supportsJSON: false,
      booleanFlags: ["--raw"]
    )
    if parsed.help {
      print(help)
      return
    }

    let terminals = try context.client.listTerminals()
    let policy: SurfaceResolutionPolicy = .regularTarget
    let terminal = try resolveSurfaceTarget(parsed.target, terminals: terminals, policy: policy)

    // Stream output
    try streamOutput(terminalId: terminal.id, raw: parsed.hasFlag("--raw"), client: context.client)
  }

  private static func streamOutput(terminalId: String, raw: Bool, client: GhosttyClient) throws {
    let stream = try client.openOutputStream(terminalId: terminalId)
    defer { stream.close() }

    // Set up signal handler for clean exit
    signal(SIGINT) { _ in
      exit(0)
    }
    signal(SIGTERM) { _ in
      exit(0)
    }

    // Read frames continuously
    do {
      while true {
        let event = try stream.readEventFrame()

        if event.name == "output",
          let data = event.data
        {
          if raw {
            FileHandle.standardOutput.write(data)
          } else {
            if let text = String(data: data, encoding: .utf8) {
              writeStdout(text)
            } else {
              // Fallback to raw if not valid UTF-8
              FileHandle.standardOutput.write(data)
            }
          }
        }
      }
    } catch {
      FileHandle.standardError.write("stream error: \(error)\n".data(using: .utf8)!)
    }
  }
}
