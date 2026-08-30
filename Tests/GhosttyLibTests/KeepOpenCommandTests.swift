import XCTest

@testable import GhosttyLib

final class KeepOpenCommandTests: XCTestCase {
  func testWrapperIsASingleLine() {
    // ScriptableGhostty types the command into a shell as initialInput, so a
    // newline-separated wrapper is submitted line by line and the pane dies.
    let wrapped = KeepOpenCommand.wrap("echo hi")
    XCTAssertFalse(wrapped.contains("\n"), "keep-open wrapper must stay a single line: \(wrapped)")
  }

  func testUserCommandRunsInASubshell() {
    // Without the subshell, a user `exit N` takes the wrapper down with it and
    // nothing reports the status.
    XCTAssertTrue(KeepOpenCommand.wrap("exit 3").hasPrefix("( exit 3 ); "))
  }

  func testExitStatusIsCapturedBeforeAnythingElseRuns() {
    let wrapped = KeepOpenCommand.wrap("false")
    XCTAssertTrue(
      wrapped.contains("); __gm_rc=$?; "),
      "status must be captured immediately after the subshell: \(wrapped)")
  }

  func testWrapperExecsAnInteractiveShellLast() {
    // The exec is load-bearing: it replaces the process image before the
    // `; exit` ScriptableGhostty appends can be reached.
    XCTAssertTrue(KeepOpenCommand.wrap("echo hi").hasSuffix("; exec \"${SHELL:-/bin/sh}\" -i"))
  }

  func testStatusLineIsPrefixedAsGhostmuxOutput() {
    XCTAssertTrue(
      KeepOpenCommand.wrap("echo hi").contains(
        "printf \"\\n[ghostmux] command exited with status %d\\n\" \"$__gm_rc\""))
  }

  func testUserCommandIsSplicedVerbatim() {
    // Quotes, ;, && and $ must survive untouched — the string is spliced in
    // command position, never re-quoted.
    let hostile = "echo \"a; b\" && echo 'it$works' && exit 7"
    XCTAssertTrue(KeepOpenCommand.wrap(hostile).contains(hostile))
  }
}
