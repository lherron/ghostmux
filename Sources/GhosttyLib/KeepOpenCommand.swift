import Foundation

/// Composes the `--keep-open` wrapper for a `--command` string.
///
/// ScriptableGhostty does not run `--command` as the pane's process. It types the
/// string into an interactive login shell as `initialInput` with `; exit\n`
/// appended (`APIHandlers.swift:274` and `:423`), so the pane's lifetime is the
/// shell's, not the command's. Three properties of this wrapper are load-bearing:
///
/// - the subshell keeps a user `exit N` from taking the wrapper down with it,
/// - `$?` is captured immediately, so the reported status is the command's,
/// - the trailing `exec` replaces the process image before the appended `exit`
///   is ever reached, which both holds the pane and leaves an interactive shell.
///
/// The wrapper must stay a single `;`-joined line: a newline-separated wrapper is
/// submitted to the shell line by line and the pane dies.
///
/// The user command is spliced in command position exactly as it is passed today,
/// so quoting semantics are unchanged from an unwrapped `--command`. Two known
/// limits follow from splicing and are deliberately not fixed here: a command
/// ending in a `#` comment, or containing a literal newline, eats the wrapper's
/// tail. Both are already broken today for the same reason.
public enum KeepOpenCommand {
  /// Status line prefix, so held-pane output is unmistakably ghostmux's and not
  /// the wrapped command's.
  public static let statusPrefix = "[ghostmux]"

  public static func wrap(_ command: String) -> String {
    "( \(command) ); __gm_rc=$?; "
      + "printf \"\\n\(statusPrefix) command exited with status %d\\n\" \"$__gm_rc\"; "
      + "exec \"${SHELL:-/bin/sh}\" -i"
  }
}
