import XCTest
@testable import GhosttyLib

final class InputPlannerTests: XCTestCase {
  private func sendKeysPolicy(appendEnter: Bool = true) -> InputPlanPolicy {
    InputPlanPolicy(
      literal: false,
      textGrouping: .joined(separator: " "),
      recognizeSpecialTokens: true,
      appendEnter: appendEnter,
      appendEnterDelayMicros: appendEnter ? 200_000 : nil
    )
  }

  private func sendKeyPolicy() -> InputPlanPolicy {
    InputPlanPolicy(
      literal: false,
      textGrouping: .individualTokens,
      recognizeSpecialTokens: true,
      appendEnter: false,
      appendEnterDelayMicros: nil
    )
  }

  private func literalPolicy() -> InputPlanPolicy {
    InputPlanPolicy(
      literal: true,
      textGrouping: .joined(separator: " "),
      recognizeSpecialTokens: false,
      appendEnter: false,
      appendEnterDelayMicros: nil
    )
  }

  func testPlainAndMultiTokenTextStayAsTextChunks() throws {
    let plain = try InputPlanner.plan(tokens: ["hello"], policy: sendKeysPolicy(appendEnter: false))
    XCTAssertEqual(plain.count, 1)
    assertText(plain[0], "hello")

    let multiToken = try InputPlanner.plan(
      tokens: ["echo", "hello"], policy: sendKeysPolicy(appendEnter: false))
    XCTAssertEqual(multiToken.count, 1)
    assertText(multiToken[0], "echo hello")

    let sendKeyTokens = try InputPlanner.plan(tokens: ["left", "right"], policy: sendKeyPolicy())
    XCTAssertEqual(sendKeyTokens.count, 2)
    assertText(sendKeyTokens[0], "left")
    assertText(sendKeyTokens[1], "right")
  }

  func testTokenModeFlushesTextAroundSpecialKeys() throws {
    let plan = try InputPlanner.plan(
      tokens: ["echo", "Tab", "done", "Escape", "C-c"],
      policy: sendKeysPolicy(appendEnter: false)
    )

    XCTAssertEqual(plan.count, 5)
    assertText(plan[0], "echo")
    assertKey(plan[1], key: "tab")
    assertText(plan[2], "done")
    assertKey(plan[3], key: "escape")
    assertKey(plan[4], key: "c", mods: ["ctrl"])
  }

  func testLiteralModeDoesNotInterpretSpecialLookingTokens() throws {
    let plan = try InputPlanner.plan(tokens: ["Tab", "C-c", "Escape"], policy: literalPolicy())

    XCTAssertEqual(plan.count, 1)
    assertText(plan[0], "Tab C-c Escape")
  }

  func testInvalidControlFormsAreErrorsOnlyInTokenMode() throws {
    XCTAssertThrowsError(
      try InputPlanner.plan(tokens: ["C-"], policy: sendKeysPolicy(appendEnter: false)))
    XCTAssertThrowsError(
      try InputPlanner.plan(
        tokens: ["Ctrl-NotAKey"], policy: sendKeysPolicy(appendEnter: false)))

    let literal = try InputPlanner.plan(tokens: ["C-", "Ctrl-NotAKey"], policy: literalPolicy())
    XCTAssertEqual(literal.count, 1)
    assertText(literal[0], "C- Ctrl-NotAKey")
  }

  func testSendKeysAppendsEnterByDefaultAndNoEnterOmitsIt() throws {
    let defaultPlan = try InputPlanner.plan(tokens: ["echo", "ok"], policy: sendKeysPolicy())
    XCTAssertEqual(defaultPlan.count, 2)
    assertText(defaultPlan[0], "echo ok")
    assertKey(defaultPlan[1], key: "enter")

    let noEnterPlan = try InputPlanner.plan(
      tokens: ["echo", "ok"], policy: sendKeysPolicy(appendEnter: false))
    XCTAssertEqual(noEnterPlan.count, 1)
    assertText(noEnterPlan[0], "echo ok")
  }

  private func assertText(
    _ operation: InputPlanOperation,
    _ expected: String,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    guard case .text(let actual) = operation else {
      return XCTFail("expected text operation, got \(operation)", file: file, line: line)
    }
    XCTAssertEqual(actual, expected, file: file, line: line)
  }

  private func assertKey(
    _ operation: InputPlanOperation,
    key expectedKey: String,
    mods expectedMods: [String] = [],
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    guard case .key(let stroke) = operation else {
      return XCTFail("expected key operation, got \(operation)", file: file, line: line)
    }
    XCTAssertEqual(stroke.key, expectedKey, file: file, line: line)
    XCTAssertEqual(stroke.mods, expectedMods, file: file, line: line)
  }
}
