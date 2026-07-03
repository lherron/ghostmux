import Foundation
import GhosttyLib

struct ScreenshotCommand: GhostmuxCommand {
  static let name = "screenshot"
  static let aliases = ["shot"]
  static let help = """
    Usage:
      ghostmux screenshot <uuid|slug> [options]
      ghostmux screenshot -t <uuid|slug> [options]

    Options:
      -t <target>           Target terminal (UUID, UUID prefix, short id, or slug)
                            Falls back to $GHOSTTY_SURFACE_UUID if not specified
      -o, --output <path>   Output PNG path. Use '-' to write PNG bytes to stdout.
                            Defaults to /tmp/ghostmux-screenshots/<slug>-<timestamp>.png
      --json                Output JSON metadata
      -h, --help            Show this help
    """

  static func run(context: CommandContext) throws {
    var target: String?
    var outputPath: String?
    var json = false

    var i = 0
    while i < context.args.count {
      let arg = context.args[i]
      if arg == "-h" || arg == "--help" {
        print(help)
        return
      }

      if arg == "-t" {
        guard i + 1 < context.args.count else {
          throw GhosttyError.message("screenshot requires a value after -t")
        }
        try assignTarget(context.args[i + 1], to: &target)
        i += 2
        continue
      }

      if arg == "-o" || arg == "--output" {
        guard i + 1 < context.args.count else {
          throw GhosttyError.message("screenshot requires a value after \(arg)")
        }
        outputPath = context.args[i + 1]
        i += 2
        continue
      }

      if arg == "--json" {
        json = true
        i += 1
        continue
      }

      if arg.hasPrefix("-") {
        throw GhosttyError.message("unexpected argument: \(arg)")
      }

      try assignTarget(arg, to: &target)
      i += 1
    }

    let resolvedTarget: String
    if let target {
      resolvedTarget = target
    } else if let envTarget = resolveEnv("GHOSTTY_SURFACE_UUID") {
      resolvedTarget = envTarget
    } else {
      throw GhosttyError.message(
        "screenshot requires <uuid|slug>, -t <target>, or $GHOSTTY_SURFACE_UUID"
      )
    }

    if json && outputPath == "-" {
      throw GhosttyError.message("screenshot --json is not compatible with -o -")
    }

    let terminals = try context.client.listTerminals()
    let targetTerminal = try resolveScreenshotTarget(resolvedTarget, terminals: terminals)
    let screenshot = try context.client.getScreenshot(terminalId: targetTerminal.id)

    let path: String?
    if outputPath == "-" {
      FileHandle.standardOutput.write(screenshot.data)
      path = nil
    } else {
      let destination = outputPath ?? defaultOutputPath(for: targetTerminal)
      try writeScreenshot(screenshot.data, to: destination)
      path = destination
    }

    if json {
      var payload: [String: Any] = [
        "id": screenshot.id,
        "name": NameGenerator.nameFromUUID(targetTerminal.id),
        "short_id": NameGenerator.shortUUID(targetTerminal.id),
        "mime_type": screenshot.mimeType,
        "width": screenshot.width,
        "height": screenshot.height,
        "bytes": screenshot.data.count,
      ]
      payload["path"] = path != nil ? path! : NSNull()
      writeJSON(payload)
    } else if let path {
      print(path)
    }
  }

  private static func assignTarget(_ value: String, to target: inout String?) throws {
    if target != nil {
      throw GhosttyError.message("screenshot accepts only one target")
    }
    target = value
  }

  private static func resolveScreenshotTarget(
    _ target: String,
    terminals: [Terminal]
  ) throws -> Terminal {
    let lowerTarget = target.lowercased()

    if let exactId = terminals.first(where: { $0.id.lowercased() == lowerTarget }) {
      return exactId
    }

    let slugMatches = terminals.filter {
      NameGenerator.nameFromUUID($0.id).lowercased() == lowerTarget
    }
    if slugMatches.count == 1 {
      return slugMatches[0]
    }
    if slugMatches.count > 1 {
      throw GhosttyError.message(
        "ambiguous terminal slug '\(target)': \(formatMatches(slugMatches))"
      )
    }

    let shortMatches = terminals.filter {
      NameGenerator.shortUUID($0.id).lowercased() == lowerTarget
    }
    if shortMatches.count == 1 {
      return shortMatches[0]
    }
    if shortMatches.count > 1 {
      throw GhosttyError.message(
        "ambiguous terminal short id '\(target)': \(formatMatches(shortMatches))"
      )
    }

    let prefixMatches = terminals.filter { $0.id.lowercased().hasPrefix(lowerTarget) }
    if prefixMatches.count == 1 {
      return prefixMatches[0]
    }
    if prefixMatches.count > 1 {
      throw GhosttyError.message(
        "ambiguous terminal UUID prefix '\(target)': \(formatMatches(prefixMatches))"
      )
    }

    throw GhosttyError.message(
      "can't find terminal: \(target) (expected UUID or slug from list-surfaces)"
    )
  }

  private static func formatMatches(_ terminals: [Terminal]) -> String {
    terminals.map { "\(NameGenerator.nameFromUUID($0.id))=\($0.id)" }.joined(separator: ", ")
  }

  private static func defaultOutputPath(for terminal: Terminal) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
    let timestamp = formatter.string(from: Date())
    let name = NameGenerator.nameFromUUID(terminal.id)
    return "/tmp/ghostmux-screenshots/\(name)-\(timestamp).png"
  }

  private static func writeScreenshot(_ data: Data, to path: String) throws {
    let url = URL(fileURLWithPath: path)
    let directory = url.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try data.write(to: url, options: .atomic)
  }
}
