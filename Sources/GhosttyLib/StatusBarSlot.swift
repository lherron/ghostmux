import Foundation

/// Which programmable status bar a `statusbar` call addresses.
///
/// ScriptableGhostty renders the secondary bar directly under the primary one, with
/// independent visibility. Builds that predate the second slot ignore an unknown `bar`
/// key on POST, so callers must probe with `getStatusBar` before mutating `.secondary`.
public enum StatusBarSlot: String {
  case primary
  case secondary

  /// The slot used when `--bar` is omitted.
  public static let defaultSlot = StatusBarSlot.primary

  /// Parses a user-supplied `--bar` value; nil when the value is not a known slot.
  public static func parse(_ raw: String) -> StatusBarSlot? {
    StatusBarSlot(rawValue: raw.trimmingCharacters(in: .whitespaces).lowercased())
  }

  /// Parses a user-supplied `--bar` value or throws the flag-specific error.
  public static func require(_ raw: String) throws -> StatusBarSlot {
    guard let slot = parse(raw) else {
      throw GhosttyError.message("--bar must be primary or secondary")
    }
    return slot
  }

  /// Value to put on the wire, or nil for the default slot so requests stay
  /// byte-identical to what pre-`bar` Ghostty builds already accept.
  public var wireValue: String? {
    self == .primary ? nil : rawValue
  }

  /// Raised when a mutating secondary-bar call reaches a Ghostty that has no second
  /// slot. Must contain "unsupported": hrc-viewer's `isUnsupportedCommandError` keys
  /// on that word.
  public static let unsupportedMessage =
    "secondary status bar unsupported by this Ghostty (upgrade scriptable-ghostty)"
}
