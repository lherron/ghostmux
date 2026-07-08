import Foundation
import GhosttyLib

struct CapturePaneCommand: GhostmuxCommand {
  static let name = "capture-pane"
  static let aliases = ["capturep"]
  static let help = commandHelp(
    """
    Usage:
      ghostmux capture-pane -t <target> [options]

    Options:
      -t <target>           Target terminal (UUID, title, or UUID prefix)
                            Falls back to $GHOSTTY_SURFACE_UUID if not specified
      -S <start>            Start line (0 = first visible line, - = history start)
      -E <end>              End line (0 = first visible line, - = visible end)
      --selection           Capture current selection text
      -p                    Print to stdout (default in ghostmux)
      --json                Output JSON
      -h, --help            Show this help
    """)

  private enum LineSpec {
    case dash
    case value(Int)
  }

  static func run(context: CommandContext) throws {
    var startSpec: LineSpec?
    var endSpec: LineSpec?

    let unsupportedFlags: Set<String> = ["-a", "-e", "-P", "-q", "-C", "-J", "-M", "-N", "-T"]
    let parsed = try parseCommandArguments(
      context.args,
      booleanFlags: unsupportedFlags.union(["--selection", "-p"]),
      valueFlags: ["-S", "-E", "-b"]
    )
    if parsed.help {
      print(help)
      return
    }

    if parsed.value(for: "-b") != nil {
      throw GhosttyError.message("capture-pane buffers are not supported in ghostmux")
    }

    if let unsupported = parsed.flagOrder.first(where: { unsupportedFlags.contains($0) }) {
      throw GhosttyError.message("capture-pane flag not supported: \(unsupported)")
    }

    if let rawStart = parsed.value(for: "-S") {
      startSpec = try parseLineSpec(rawStart)
    }
    if let rawEnd = parsed.value(for: "-E") {
      endSpec = try parseLineSpec(rawEnd)
    }

    let terminals = try context.client.listTerminals()
    let policy: SurfaceResolutionPolicy = .regularTarget
    let targetTerminal = try resolveSurfaceTarget(
      parsed.target, terminals: terminals, policy: policy)

    if parsed.hasFlag("--selection") {
      if startSpec != nil || endSpec != nil {
        throw GhosttyError.message("capture-pane --selection is not compatible with -S/-E")
      }
      let selectionText = try context.client.getSelectionContents(terminalId: targetTerminal.id)
      if parsed.json {
        let payload: [String: Any] = ["selection": selectionText ?? NSNull()]
        writeJSON(payload)
      } else if let selectionText {
        writeStdout(selectionText)
      }
      return
    }

    if startSpec == nil && endSpec == nil {
      let visible = try context.client.getVisibleContents(terminalId: targetTerminal.id)
      if parsed.json {
        writeJSON(["contents": visible])
      } else {
        writeStdout(visible)
      }
      return
    }

    let screen = try context.client.getScreenContents(terminalId: targetTerminal.id)
    let screenLines = splitLines(screen)
    if screenLines.isEmpty {
      return
    }

    let visibleLineCount = try resolveVisibleLineCount(
      terminal: targetTerminal,
      client: context.client
    )
    let visibleStart = max(0, screenLines.count - visibleLineCount)
    let visibleEnd = max(visibleStart, screenLines.count - 1)

    var startIndex = resolveStartIndex(spec: startSpec, visibleStart: visibleStart)
    var endIndex = resolveEndIndex(
      spec: endSpec, visibleStart: visibleStart, visibleEnd: visibleEnd)

    startIndex = clampIndex(startIndex, max: screenLines.count - 1)
    endIndex = clampIndex(endIndex, max: screenLines.count - 1)

    if endIndex < startIndex {
      return
    }

    let output = screenLines[startIndex...endIndex].joined(separator: "\n")
    if parsed.json {
      writeJSON(["contents": output])
    } else {
      writeStdout(output)
    }
  }

  private static func parseLineSpec(_ value: String) throws -> LineSpec {
    if value == "-" {
      return .dash
    }
    guard let parsed = Int(value) else {
      throw GhosttyError.message("invalid line value: \(value)")
    }
    return .value(parsed)
  }

  private static func resolveVisibleLineCount(
    terminal: Terminal,
    client: GhosttyClient
  ) throws -> Int {
    if let rows = terminal.rows, rows > 0 {
      return rows
    }
    let visible = try client.getVisibleContents(terminalId: terminal.id)
    return max(1, splitLines(visible).count)
  }

  private static func resolveStartIndex(spec: LineSpec?, visibleStart: Int) -> Int {
    switch spec {
    case nil:
      return visibleStart
    case .dash:
      return 0
    case .value(let value):
      return visibleStart + value
    }
  }

  private static func resolveEndIndex(spec: LineSpec?, visibleStart: Int, visibleEnd: Int) -> Int {
    switch spec {
    case nil:
      return visibleEnd
    case .dash:
      return visibleEnd
    case .value(let value):
      return visibleStart + value
    }
  }

  private static func clampIndex(_ index: Int, max: Int) -> Int {
    if max < 0 {
      return 0
    }
    return Swift.max(0, Swift.min(index, max))
  }

  private static func splitLines(_ text: String) -> [String] {
    return text.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
  }
}
