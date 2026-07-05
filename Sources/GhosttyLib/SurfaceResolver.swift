import Foundation

public enum SurfaceSelector: Equatable {
  case none
  case argument(String)
  case environment(String)
  case focused
}

public enum SurfaceSelectorMode: Hashable, CustomStringConvertible {
  case exactUUID
  case uuidPrefix
  case title
  case friendlyName

  public var description: String {
    switch self {
    case .exactUUID:
      return "exact UUID"
    case .uuidPrefix:
      return "UUID prefix or short id"
    case .title:
      return "title"
    case .friendlyName:
      return "friendly name"
    }
  }
}

public enum SurfaceFallbackMode: Hashable {
  case environment(String)
  case focused
}

public struct SurfaceResolutionPolicy {
  public let allowedModes: [SurfaceSelectorMode]
  public let fallbackModes: [SurfaceFallbackMode]

  public init(
    allowedModes: [SurfaceSelectorMode],
    fallbackModes: [SurfaceFallbackMode]
  ) {
    self.allowedModes = allowedModes
    self.fallbackModes = fallbackModes
  }
}

extension SurfaceResolutionPolicy {
  public static let regularTarget = SurfaceResolutionPolicy(
    allowedModes: [.exactUUID, .title, .uuidPrefix, .friendlyName],
    fallbackModes: [.environment("GHOSTTY_SURFACE_UUID")]
  )

  public static let focusedTarget = SurfaceResolutionPolicy(
    allowedModes: [.exactUUID, .title, .uuidPrefix, .friendlyName],
    fallbackModes: [.environment("GHOSTTY_SURFACE_UUID"), .focused]
  )

  public static let screenshotTarget = SurfaceResolutionPolicy(
    allowedModes: [.exactUUID, .friendlyName, .uuidPrefix],
    fallbackModes: [.environment("GHOSTTY_SURFACE_UUID")]
  )

  public static let ghostchatSend = SurfaceResolutionPolicy(
    allowedModes: [.friendlyName, .exactUUID, .uuidPrefix, .title],
    fallbackModes: []
  )
}

public enum SurfaceResolutionError: Error {
  case missingSelector
  case notFound(selector: String, allowedModes: [SurfaceSelectorMode])
  case ambiguous(selector: String, matches: [Terminal])
}

extension SurfaceResolutionError {
  public static func format(_ error: Error) -> String {
    guard let error = error as? SurfaceResolutionError else {
      return String(describing: error)
    }

    switch error {
    case .missingSelector:
      return "target selector required (provide -t <target> or set $GHOSTTY_SURFACE_UUID)"
    case .notFound(let selector, let allowedModes):
      let expected = allowedModes.map(\.description).joined(separator: ", ")
      return "can't find terminal: \(selector) (expected \(expected))"
    case .ambiguous(let selector, let matches):
      return "ambiguous terminal selector '\(selector)': \(formatMatches(matches))"
    }
  }

  private static func formatMatches(_ matches: [Terminal]) -> String {
    matches.map { terminal in
      let name = NameGenerator.nameFromUUID(terminal.id)
      let shortId = NameGenerator.shortUUID(terminal.id)
      return "\(name) short_id=\(shortId) id=\(terminal.id) title=\"\(terminal.title)\""
    }
    .joined(separator: ", ")
  }
}

public struct SurfaceResolver {
  public typealias EnvironmentLookup = (String) -> String?

  private let terminals: [Terminal]
  private let environment: EnvironmentLookup

  public init(
    terminals: [Terminal],
    environment: @escaping EnvironmentLookup = resolveEnv
  ) {
    self.terminals = terminals
    self.environment = environment
  }

  public func resolve(
    _ selector: SurfaceSelector,
    policy: SurfaceResolutionPolicy
  ) throws -> Terminal {
    switch selector {
    case .argument(let value):
      return try resolveArgument(value, policy: policy)
    case .environment(let name):
      guard let value = environment(name), !value.isEmpty else {
        throw SurfaceResolutionError.missingSelector
      }
      return try resolveArgument(value, policy: policy)
    case .focused:
      return try resolveFocused(selector: "focused terminal")
    case .none:
      return try resolveFallback(policy: policy)
    }
  }

  private func resolveFallback(policy: SurfaceResolutionPolicy) throws -> Terminal {
    var sawFallback = false
    for fallback in policy.fallbackModes {
      sawFallback = true
      switch fallback {
      case .environment(let name):
        guard let value = environment(name), !value.isEmpty else {
          continue
        }
        return try resolveArgument(value, policy: policy)
      case .focused:
        if let focused = try? resolveFocused(selector: "focused terminal") {
          return focused
        }
      }
    }

    if sawFallback, policy.fallbackModes.contains(.focused) {
      throw SurfaceResolutionError.notFound(
        selector: "focused terminal",
        allowedModes: policy.allowedModes
      )
    }
    throw SurfaceResolutionError.missingSelector
  }

  private func resolveArgument(
    _ value: String,
    policy: SurfaceResolutionPolicy
  ) throws -> Terminal {
    let selector = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !selector.isEmpty else {
      throw SurfaceResolutionError.missingSelector
    }

    for mode in policy.allowedModes {
      let matches = matches(for: selector, mode: mode)
      if matches.count == 1 {
        return matches[0]
      }
      if matches.count > 1 {
        throw SurfaceResolutionError.ambiguous(selector: selector, matches: matches)
      }
    }

    throw SurfaceResolutionError.notFound(selector: selector, allowedModes: policy.allowedModes)
  }

  private func resolveFocused(selector: String) throws -> Terminal {
    let matches = terminals.filter(\.focused)
    if matches.count == 1 {
      return matches[0]
    }
    if matches.count > 1 {
      throw SurfaceResolutionError.ambiguous(selector: selector, matches: matches)
    }
    throw SurfaceResolutionError.notFound(selector: selector, allowedModes: [])
  }

  private func matches(for selector: String, mode: SurfaceSelectorMode) -> [Terminal] {
    let lowerSelector = selector.lowercased()
    switch mode {
    case .exactUUID:
      return terminals.filter { $0.id.lowercased() == lowerSelector }
    case .uuidPrefix:
      return terminals.filter { $0.id.lowercased().hasPrefix(lowerSelector) }
    case .friendlyName:
      return terminals.filter {
        NameGenerator.nameFromUUID($0.id).lowercased() == lowerSelector
      }
    case .title:
      let exactMatches = terminals.filter { $0.title.lowercased() == lowerSelector }
      if !exactMatches.isEmpty {
        return exactMatches
      }
      return terminals.filter { $0.title.lowercased().contains(lowerSelector) }
    }
  }
}
