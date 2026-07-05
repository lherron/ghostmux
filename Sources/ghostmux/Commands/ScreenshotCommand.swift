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

    if json && outputPath == "-" {
      throw GhosttyError.message("screenshot --json is not compatible with -o -")
    }

    let terminals = try context.client.listTerminals()
    let policy: SurfaceResolutionPolicy = .screenshotTarget
    let targetTerminal: Terminal
    do {
      targetTerminal = try SurfaceResolver(terminals: terminals).resolve(
        target.map(SurfaceSelector.argument) ?? .none,
        policy: policy
      )
    } catch let error as SurfaceResolutionError {
      throw GhosttyError.message(SurfaceResolutionError.format(error))
    }
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
