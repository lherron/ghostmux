import Foundation

public enum InputPlanOperation {
  case text(String)
  case key(KeyStroke)
}

public enum InputTextGrouping {
  case individualTokens
  case joined(separator: String)
}

public struct InputPlanPolicy {
  public let literal: Bool
  public let textGrouping: InputTextGrouping
  public let recognizeSpecialTokens: Bool
  public let appendEnter: Bool
  public let appendEnterDelayMicros: UInt32?

  public init(
    literal: Bool,
    textGrouping: InputTextGrouping,
    recognizeSpecialTokens: Bool,
    appendEnter: Bool,
    appendEnterDelayMicros: UInt32?
  ) {
    self.literal = literal
    self.textGrouping = textGrouping
    self.recognizeSpecialTokens = recognizeSpecialTokens
    self.appendEnter = appendEnter
    self.appendEnterDelayMicros = appendEnterDelayMicros
  }
}

public enum InputPlanner {
  public static func plan(tokens: [String], policy: InputPlanPolicy) throws -> [InputPlanOperation]
  {
    var operations: [InputPlanOperation] = []
    var textBuffer: [String] = []

    func flushText() {
      switch policy.textGrouping {
      case .individualTokens:
        operations.append(contentsOf: textBuffer.map { .text($0) })
      case .joined(let separator):
        if !textBuffer.isEmpty {
          operations.append(.text(textBuffer.joined(separator: separator)))
        }
      }
      textBuffer.removeAll()
    }

    for token in tokens {
      if policy.literal || !policy.recognizeSpecialTokens {
        textBuffer.append(token)
        continue
      }

      // Canonical parsing handles Tab, Escape, C-c and invalid key/control forms.
      if let keyStroke = try keyStrokeForNamedOrControlToken(token) {
        flushText()
        operations.append(.key(keyStroke))
      } else {
        textBuffer.append(token)
      }
    }

    flushText()

    if policy.appendEnter {
      operations.append(
        .key(KeyStroke(key: "enter", mods: [], text: "\n", unshiftedCodepoint: 0x0A)))
    }

    return operations
  }
}
