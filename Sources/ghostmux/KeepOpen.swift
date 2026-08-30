import GhostmuxCommandParsing
import GhosttyLib

/// Resolves the `command` field sent to the API for a command that supports
/// `--keep-open`. Without the flag the user string is passed through unchanged,
/// so default pane lifetime is untouched.
///
/// `--keep-open` without `--command` is a hard usage error rather than a silent
/// no-op: a command-less pane is already a persistent shell, and a flag that
/// quietly does nothing trains callers to trust it where it does not apply.
func resolvedCommand(_ parsed: CommandArgumentParseResult) throws -> String? {
  let command = parsed.value(for: "--command")
  guard parsed.hasFlag("--keep-open") else {
    return command
  }
  guard let command else {
    throw GhosttyError.message("--keep-open requires --command")
  }
  return KeepOpenCommand.wrap(command)
}
