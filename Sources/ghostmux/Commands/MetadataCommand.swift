import Foundation
import GhosttyLib

struct MetadataCommand: GhostmuxCommand {
  static let name = "metadata"
  static let aliases: [String] = []
  static let help = commandHelp(
    """
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
    """)

  static func run(context: CommandContext) throws {
    let parsed = try parseCommandArguments(
      context.args,
      positionals: .collect,
      booleanFlags: ["--window", "--resolved", "--replace", "--post"]
    )
    if parsed.help {
      print(help)
      return
    }

    guard let subcommand = parsed.positionals.first else {
      throw GhosttyError.message("metadata requires a subcommand: get, set, delete")
    }

    let terminals = try context.client.listTerminals()
    let policy: SurfaceResolutionPolicy = .regularTarget
    let targetTerminal = try resolveSurfaceTarget(
      parsed.target, terminals: terminals, policy: policy)

    let windowScope = parsed.hasFlag("--window")
    let resolved = parsed.hasFlag("--resolved")
    let replace = parsed.hasFlag("--replace")
    let post = parsed.hasFlag("--post")
    let scope = windowScope ? "window" : nil
    let extraArgs = Array(parsed.positionals.dropFirst())

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
      printMetadata(data, json: parsed.json)

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
      if parsed.json {
        writeJSON(["data": responseData])
      }

    case "delete":
      if resolved || replace || post {
        throw GhosttyError.message(
          "metadata delete does not accept --resolved, --replace, or --post")
      }
      if !extraArgs.isEmpty {
        throw GhosttyError.message("metadata delete does not take extra arguments")
      }
      let responseData = try context.client.deleteMetadata(
        terminalId: targetTerminal.id,
        scope: scope
      )
      if parsed.json {
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
