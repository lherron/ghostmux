import Foundation
import GhosttyLib

struct MetadataCommand: GhostmuxCommand {
    static let name = "metadata"
    static let aliases: [String] = []
    static let help = """
    Usage:
      ghostmux metadata get -t <target> [--window] [--resolved] [--json]
      ghostmux metadata set -t <target> '<json-object>' [--window] [--replace] [--post] [--json]
      ghostmux metadata delete -t <target> [--window] [--json]

    Options:
      -t <target>           Target terminal (UUID, title, or UUID prefix)
                            Falls back to $GHOSTTY_SURFACE_UUID if not specified
      --window              Use window-level metadata instead of surface-level
      --resolved            Return window metadata overlaid by surface metadata (get only)
      --replace             Replace metadata (PUT) instead of merge (PATCH)
      --post                Use POST instead of PATCH for merges
      --json                Output JSON
      -h, --help            Show this help
    """

    static func run(context: CommandContext) throws {
        var target: String?
        var positional: [String] = []
        var json = false
        var windowScope = false
        var resolved = false
        var replace = false
        var post = false

        var i = 0
        while i < context.args.count {
            let arg = context.args[i]
            if arg == "-t", i + 1 < context.args.count {
                target = context.args[i + 1]
                i += 2
                continue
            }

            if arg == "--window" {
                windowScope = true
                i += 1
                continue
            }

            if arg == "--resolved" {
                resolved = true
                i += 1
                continue
            }

            if arg == "--replace" {
                replace = true
                i += 1
                continue
            }

            if arg == "--post" {
                post = true
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

        guard let subcommand = positional.first else {
            throw GhosttyError.message("metadata requires a subcommand: get, set, delete")
        }

        let resolvedTarget: String
        if let target {
            resolvedTarget = target
        } else if let envTarget = ProcessInfo.processInfo.environment["GHOSTTY_SURFACE_UUID"] {
            resolvedTarget = envTarget
        } else {
            throw GhosttyError.message("metadata requires -t <target> or $GHOSTTY_SURFACE_UUID")
        }

        let terminals = try context.client.listTerminals()
        guard let targetTerminal = resolveTarget(resolvedTarget, terminals: terminals) else {
            throw GhosttyError.message("can't find terminal: \(resolvedTarget)")
        }

        let scope = windowScope ? "window" : nil
        let extraArgs = Array(positional.dropFirst())

        switch subcommand {
        case "get":
            if replace || post {
                throw GhosttyError.message("metadata get does not accept --replace or --post")
            }
            if !extraArgs.isEmpty {
                throw GhosttyError.message("metadata get does not take extra arguments")
            }
            let data = try context.client.getMetadata(
                terminalId: targetTerminal.id,
                scope: scope,
                resolved: resolved ? true : nil
            )
            printMetadata(data, json: json)

        case "set":
            if resolved {
                throw GhosttyError.message("metadata set does not accept --resolved")
            }
            guard extraArgs.count == 1 else {
                throw GhosttyError.message("metadata set requires a single JSON object argument")
            }
            let payload = try parseJSONObject(extraArgs[0])
            let responseData: [String: Any]
            if replace {
                responseData = try context.client.replaceMetadata(
                    terminalId: targetTerminal.id,
                    data: payload,
                    scope: scope
                )
            } else {
                let method = post ? "POST" : "PATCH"
                responseData = try context.client.mergeMetadata(
                    terminalId: targetTerminal.id,
                    data: payload,
                    scope: scope,
                    method: method
                )
            }
            if json {
                writeJSON(["data": responseData])
            }

        case "delete":
            if resolved || replace || post {
                throw GhosttyError.message("metadata delete does not accept --resolved, --replace, or --post")
            }
            if !extraArgs.isEmpty {
                throw GhosttyError.message("metadata delete does not take extra arguments")
            }
            let responseData = try context.client.deleteMetadata(
                terminalId: targetTerminal.id,
                scope: scope
            )
            if json {
                writeJSON(["data": responseData])
            }

        default:
            throw GhosttyError.message("unknown metadata subcommand: \(subcommand)")
        }
    }

    private static func parseJSONObject(_ raw: String) throws -> [String: Any] {
        guard let data = raw.data(using: .utf8) else {
            throw GhosttyError.message("metadata JSON must be valid UTF-8")
        }
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = object as? [String: Any] else {
            throw GhosttyError.message("metadata JSON must be an object")
        }
        return dict
    }

    private static func printMetadata(_ data: [String: Any], json: Bool) {
        let payload: [String: Any] = ["data": data]
        if json {
            writeJSON(payload)
            return
        }

        if let output = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        ), let text = String(data: output, encoding: .utf8) {
            print(text)
            return
        }

        print("{}")
    }
}
