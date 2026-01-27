#!/usr/bin/env swift
import Foundation
import GhosttyLib

// MARK: - Help Text

private let infoText = """
ghostchat - Inter-agent messaging for Claude Code sessions

ABOUT
  ghostchat enables Claude Code agents running in different terminal sessions
  to communicate with each other by sending text messages. Each terminal has
  a unique friendly name derived from its UUID.

YOUR IDENTITY
  Name: %NAME%
  UUID: %UUID%

PROTOCOL
  Messages are sent as: [ghostchat:<sender-name>] <message>

  When you receive a message starting with [ghostchat:...], another agent
  is communicating with you. Parse the sender name from the brackets to
  identify who sent it.

COMMANDS
  ghostchat info          Show this tutorial and your identity
  ghostchat list          List all available terminals with their names
  ghostchat send <target> <message>
                          Send a message to another terminal

  <target> can be:
    - Friendly name (e.g., "swift-falcon")
    - UUID prefix (e.g., "550e8400")
    - Full UUID
    - Terminal title (partial match)

EXAMPLES
  ghostchat list
  ghostchat send swift-falcon "Hello, I need help with the API"
  ghostchat send 550e8400 "Can you check the test results?"

TIPS
  - Messages are single-line only (newlines are removed)
  - Use quotes around messages with spaces
  - Run 'ghostchat list' to see available targets
"""

private let usage = """
ghostchat - Inter-agent messaging for Claude Code sessions

Usage:
  ghostchat <command> [options]

Commands:
  info                    Show tutorial and your identity
  list                    List all terminals with friendly names
  send <target> <msg>     Send a message to another terminal

Options:
  -h, --help              Show this help
  --json                  Output JSON (for list command)

Run 'ghostchat info' for detailed usage instructions.
"""

// MARK: - Main

func getMyUUID() -> String? {
    ProcessInfo.processInfo.environment["GHOSTTY_SURFACE_UUID"]
}

func printInfo() {
    let myUUID = getMyUUID() ?? "(not in a Ghostty terminal)"
    let myName = myUUID != "(not in a Ghostty terminal)"
        ? NameGenerator.nameFromUUID(myUUID)
        : "(unknown)"

    let output = infoText
        .replacingOccurrences(of: "%NAME%", with: myName)
        .replacingOccurrences(of: "%UUID%", with: myUUID)
    print(output)
}

func printList(json: Bool) throws {
    let client = GhosttyClient(socketPath: defaultSocketPath())
    let terminals = try client.listTerminals()

    let myUUID = getMyUUID()

    if json {
        let payload = terminals.map { terminal -> [String: Any] in
            var entry: [String: Any] = [
                "id": terminal.id,
                "name": NameGenerator.nameFromUUID(terminal.id),
                "short_id": NameGenerator.shortUUID(terminal.id),
                "title": terminal.title,
                "focused": terminal.focused
            ]
            if let cwd = terminal.workingDirectory {
                entry["working_directory"] = cwd
            }
            if terminal.id == myUUID {
                entry["is_me"] = true
            }
            return entry
        }
        writeJSON(["terminals": payload])
        return
    }

    if terminals.isEmpty {
        print("(no terminals found)")
        return
    }

    for terminal in terminals {
        let name = NameGenerator.nameFromUUID(terminal.id)
        let shortId = NameGenerator.shortUUID(terminal.id)
        let isMe = terminal.id == myUUID ? " (you)" : ""
        let focused = terminal.focused ? " *" : ""

        var titlePart = terminal.title
        if let cwd = terminal.workingDirectory {
            let shortCwd = (cwd as NSString).lastPathComponent
            titlePart += " (\(shortCwd))"
        }

        print("\(name)\(isMe)  \(shortId)  \(titlePart)\(focused)")
    }
}

func sendMessage(target: String, messageParts: [String]) throws {
    guard let myUUID = getMyUUID() else {
        throw GhosttyError.message("$GHOSTTY_SURFACE_UUID not set - are you in a Ghostty terminal?")
    }

    if messageParts.isEmpty {
        throw GhosttyError.message("send requires a message")
    }

    let client = GhosttyClient(socketPath: defaultSocketPath())
    let terminals = try client.listTerminals()

    // Try to resolve target by friendly name first
    let resolvedTerminal: Terminal?
    let lowerTarget = target.lowercased()

    // Check friendly name match
    if let byName = terminals.first(where: {
        NameGenerator.nameFromUUID($0.id).lowercased() == lowerTarget
    }) {
        resolvedTerminal = byName
    } else {
        // Fall back to standard resolution (UUID, title, prefix)
        resolvedTerminal = resolveTarget(target, terminals: terminals)
    }

    guard let terminal = resolvedTerminal else {
        throw GhosttyError.message("cannot find terminal: \(target)")
    }

    if terminal.id == myUUID {
        throw GhosttyError.message("cannot send to yourself")
    }

    // Build message - concatenate all parts and normalize to single line
    let rawMessage = messageParts.joined(separator: " ")
    let singleLineMessage = rawMessage
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: "\r", with: " ")
        .trimmingCharacters(in: .whitespaces)

    let myName = NameGenerator.nameFromUUID(myUUID)
    let fullMessage = "[ghostchat:\(myName)] \(singleLineMessage)"

    // Send using text input + enter
    try client.sendText(terminalId: terminal.id, text: fullMessage)

    // Small delay then send Enter
    usleep(200000)  // 200ms
    let enterStroke = KeyStroke(key: "enter", mods: [], text: "\n", unshiftedCodepoint: 0x0A)
    try client.sendKey(terminalId: terminal.id, stroke: enterStroke)

    let targetName = NameGenerator.nameFromUUID(terminal.id)
    print("Sent to \(targetName)")
}

func main() {
    let args = Array(CommandLine.arguments.dropFirst())

    if args.isEmpty {
        print(usage)
        return
    }

    let command = args[0]

    if command == "-h" || command == "--help" {
        print(usage)
        return
    }

    do {
        switch command {
        case "info":
            printInfo()

        case "list", "ls":
            let json = args.contains("--json")
            try printList(json: json)

        case "send":
            if args.count < 3 {
                throw GhosttyError.message("usage: ghostchat send <target> <message>")
            }
            let target = args[1]
            let messageParts = Array(args.dropFirst(2))
            try sendMessage(target: target, messageParts: messageParts)

        default:
            fputs("error: unknown command '\(command)'\n", stderr)
            fputs("run 'ghostchat --help' for usage\n", stderr)
            exit(1)
        }
    } catch let error as GhosttyError {
        fputs("error: \(error.description)\n", stderr)
        exit(1)
    } catch {
        fputs("error: \(error)\n", stderr)
        exit(1)
    }
}

main()
