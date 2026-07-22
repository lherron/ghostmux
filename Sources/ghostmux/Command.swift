import Foundation
import GhostmuxCommandParsing
import GhosttyLib

struct CommandContext {
  let args: [String]
  let client: GhosttyClient
}

protocol GhostmuxCommand {
  static var name: String { get }
  static var aliases: [String] { get }
  static var help: String { get }
  static func run(context: CommandContext) throws
}

func commandHelp(_ raw: String) -> String {
  raw
}

func terminalSummary(_ terminal: Terminal, includeFocusStatus: Bool = true) -> String {
  let name = NameGenerator.nameFromUUID(terminal.id)
  let shortId = String(terminal.id.prefix(8))

  var output = "Created pane: \(name) (\(shortId))"

  if includeFocusStatus && terminal.focused {
    output += " - now focused"
  }

  if let cwd = terminal.workingDirectory {
    output += "\nWorking directory: \(cwd)"
  }

  if let columns = terminal.columns, let rows = terminal.rows {
    output += "\nSize: \(columns)x\(rows)"
  }

  return output
}

func resolveSurfaceTarget(
  _ target: String?,
  terminals: [Terminal],
  policy: SurfaceResolutionPolicy
) throws -> Terminal {
  do {
    return try SurfaceResolver(terminals: terminals).resolve(
      target.map(SurfaceSelector.argument) ?? .none,
      policy: policy
    )
  } catch let error as SurfaceResolutionError {
    throw GhosttyError.message(SurfaceResolutionError.format(error))
  }
}

func parseCommandArguments(
  _ args: [String],
  supportsJSON: Bool = true,
  targetAliases: Set<String> = ["-t"],
  repeatedTarget: CommandArgumentParseOptions.RepeatedTargetPolicy = .lastWins,
  positionals: CommandArgumentParseOptions.PositionalPolicy = .reject,
  booleanFlags: Set<String> = [],
  valueFlags: Set<String> = [],
  flagLikePositionals: Bool = false
) throws -> CommandArgumentParseResult {
  try CommandArgumentParser.parse(
    args,
    options: CommandArgumentParseOptions(
      supportsJSON: supportsJSON,
      targetAliases: targetAliases,
      repeatedTarget: repeatedTarget,
      positionals: positionals,
      booleanFlags: booleanFlags,
      valueFlags: valueFlags,
      flagLikePositionals: flagLikePositionals
    )
  )
}
