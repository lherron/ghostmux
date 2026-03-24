import Foundation
import GhosttyLib

struct AttachHostSessionCommand: GhostmuxCommand {
    static let name = "attach-host-session"
    static let aliases: [String] = []
    static let help = """
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
    """

    static func run(context: CommandContext) throws {
        var target: String?
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

        guard positional.count == 1 else {
            throw GhosttyError.message("attach-host-session requires a single animata-host:// target URI")
        }

        let resolvedTarget: String
        if let target {
            resolvedTarget = target
        } else if let envTarget = resolveEnv("GHOSTTY_SURFACE_UUID") {
            resolvedTarget = envTarget
        } else {
            throw GhosttyError.message("attach-host-session requires -t <target> or $GHOSTTY_SURFACE_UUID")
        }

        let terminals = try context.client.listTerminals()
        guard let targetTerminal = resolveTarget(resolvedTarget, terminals: terminals) else {
            throw GhosttyError.message("can't find terminal: \(resolvedTarget)")
        }

        let targetUri = positional[0]
        let (hostRef, sessionName) = try parseAnimataHostURI(targetUri)

        _ = try context.client.mergeMetadata(
            terminalId: targetTerminal.id,
            data: [
                "animata_host": hostRef,
                "animata_session": sessionName,
                "animata_host_target": targetUri,
            ]
        )

        if json {
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

        let sessionName = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).removingPercentEncoding ?? ""
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
