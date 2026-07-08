import Foundation
import GhosttyLib

struct AttachHostSessionCommand: GhostmuxCommand {
  static let name = "attach-host-session"
  static let aliases: [String] = []
  static let help = commandHelp(
    """
      Usage:
        ghostmux attach-host-session -t <target> [--json] <animata-host-uri>

      Options:
        -t <target>           Target terminal (UUID, title, or UUID prefix)
                              Falls back to $GHOSTTY_SURFACE_UUID if not specified
        --json                Output JSON
        -h, --help            Show this help

      Binds a Ghostty surface to an Animata host session using an animata-host://
      or host:// URI. This is a protocol-level attach contract, not shell text
      injection.
    """)

  static func run(context: CommandContext) throws {
    let parsed = try parseCommandArguments(context.args, positionals: .collect)
    if parsed.help {
      print(help)
      return
    }

    guard parsed.positionals.count == 1 else {
      throw GhosttyError.message("attach-host-session requires a single animata-host:// target URI")
    }

    let terminals = try context.client.listTerminals()
    let policy: SurfaceResolutionPolicy = .regularTarget
    let targetTerminal = try resolveSurfaceTarget(
      parsed.target, terminals: terminals, policy: policy)

    let targetUri = parsed.positionals[0]
    let (hostRef, sessionName) = try parseAnimataHostURI(targetUri)

    _ = try context.client.mergeMetadata(
      terminalId: targetTerminal.id,
      data: [
        "animata_host": hostRef,
        "animata_session": sessionName,
        "animata_host_target": targetUri,
      ]
    )

    if parsed.json {
      writeJSON([
        "success": true,
        "terminal_id": targetTerminal.id,
        "animata_host": hostRef,
        "animata_session": sessionName,
        "target": targetUri,
      ])
    }
  }

  private static func parseAnimataHostURI(_ raw: String) throws -> (String, String) {
    guard let url = URL(string: raw) else {
      throw GhosttyError.message("attach-host-session target must be a valid URI")
    }

    guard let scheme = url.scheme, scheme == "animata-host" || scheme == "host" else {
      throw GhosttyError.message("attach-host-session target must use animata-host:// or host://")
    }

    let sessionName =
      url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).removingPercentEncoding ?? ""
    guard !sessionName.isEmpty else {
      throw GhosttyError.message("attach-host-session target is missing session path")
    }

    let hostRef = url.host?.removingPercentEncoding ?? url.host ?? ""
    guard !hostRef.isEmpty else {
      throw GhosttyError.message("attach-host-session target is missing host reference")
    }

    return (hostRef, sessionName)
  }
}
