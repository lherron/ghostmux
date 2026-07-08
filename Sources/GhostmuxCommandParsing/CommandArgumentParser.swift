public struct CommandArgumentParseOptions {
  public enum RepeatedTargetPolicy {
    case lastWins
    case reject
  }

  public enum PositionalPolicy {
    case collect
    case reject
  }

  public let supportsJSON: Bool
  public let targetAliases: Set<String>
  public let repeatedTarget: RepeatedTargetPolicy
  public let positionals: PositionalPolicy
  public let booleanFlags: Set<String>
  public let valueFlags: Set<String>
  public let flagLikePositionals: Bool

  public init(
    supportsJSON: Bool = false,
    targetAliases: Set<String> = [],
    repeatedTarget: RepeatedTargetPolicy = .lastWins,
    positionals: PositionalPolicy = .reject,
    booleanFlags: Set<String> = [],
    valueFlags: Set<String> = [],
    flagLikePositionals: Bool = false
  ) {
    self.supportsJSON = supportsJSON
    self.targetAliases = targetAliases
    self.repeatedTarget = repeatedTarget
    self.positionals = positionals
    self.booleanFlags = booleanFlags
    self.valueFlags = valueFlags
    self.flagLikePositionals = flagLikePositionals
  }
}

public struct CommandArgumentParseResult {
  public let help: Bool
  public let json: Bool
  public let target: String?
  public let positionals: [String]
  public let flags: Set<String>
  public let flagOrder: [String]
  public let values: [String: [String]]
  public let valueOrder: [(flag: String, value: String)]

  public func hasFlag(_ flag: String) -> Bool {
    flags.contains(flag)
  }

  public func value(for flag: String) -> String? {
    values[flag]?.last
  }

  public func values(for flag: String) -> [String] {
    values[flag] ?? []
  }

  public func value(forAny aliases: [String]) -> String? {
    for item in valueOrder.reversed() where aliases.contains(item.flag) {
      return item.value
    }
    return nil
  }

  public func values(forAny aliases: [String]) -> [String] {
    valueOrder.compactMap { aliases.contains($0.flag) ? $0.value : nil }
  }
}

public enum CommandArgumentParseError: Error, CustomStringConvertible {
  case missingValue(flag: String)
  case unexpectedArgument(String)
  case repeatedTarget

  public var description: String {
    switch self {
    case .missingValue(let flag):
      return "requires a value after \(flag)"
    case .unexpectedArgument(let argument):
      return "unexpected argument: \(argument)"
    case .repeatedTarget:
      return "target specified multiple times"
    }
  }
}

public enum CommandArgumentParser {
  public static func parse(
    _ args: [String],
    options: CommandArgumentParseOptions
  ) throws -> CommandArgumentParseResult {
    var help = false
    var json = false
    var target: String?
    var positionals: [String] = []
    var flags: Set<String> = []
    var flagOrder: [String] = []
    var values: [String: [String]] = [:]
    var valueOrder: [(flag: String, value: String)] = []

    var index = 0
    while index < args.count {
      let argument = args[index]

      if argument == "-h" || argument == "--help" {
        help = true
        index += 1
        continue
      }

      if options.supportsJSON && argument == "--json" {
        json = true
        index += 1
        continue
      }

      if options.targetAliases.contains(argument) {
        let value = try valueAfter(argument, in: args, at: index)
        if target != nil && options.repeatedTarget == .reject {
          throw CommandArgumentParseError.repeatedTarget
        }
        target = value
        index += 2
        continue
      }

      if options.booleanFlags.contains(argument) {
        flags.insert(argument)
        flagOrder.append(argument)
        index += 1
        continue
      }

      if options.valueFlags.contains(argument) {
        let value = try valueAfter(argument, in: args, at: index)
        values[argument, default: []].append(value)
        valueOrder.append((flag: argument, value: value))
        index += 2
        continue
      }

      if argument.hasPrefix("-") && !options.flagLikePositionals {
        throw CommandArgumentParseError.unexpectedArgument(argument)
      }

      switch options.positionals {
      case .collect:
        positionals.append(argument)
        index += 1
      case .reject:
        throw CommandArgumentParseError.unexpectedArgument(argument)
      }
    }

    return CommandArgumentParseResult(
      help: help,
      json: json,
      target: target,
      positionals: positionals,
      flags: flags,
      flagOrder: flagOrder,
      values: values,
      valueOrder: valueOrder
    )
  }

  private static func valueAfter(_ flag: String, in args: [String], at index: Int) throws -> String
  {
    guard index + 1 < args.count else {
      throw CommandArgumentParseError.missingValue(flag: flag)
    }
    return args[index + 1]
  }
}
