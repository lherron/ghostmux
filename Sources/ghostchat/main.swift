#!/usr/bin/env swift
import Foundation
import GhosttyLib

// MARK: - Help Text

private let infoText = """
ghostchat - Inter-agent messaging for Claude Code sessions

ABOUT
  ghostchat enables Claude Code agents running in different terminal sessions
  to communicate with each other by sending text messages. Each terminal has
  a unique friendly name derived from its UUID.  Chat will be injected as a user
  message with appropraite tagging to identify the sender.

YOUR IDENTITY
  Name: %NAME%
  UUID: %UUID%

PROTOCOL
  Messages are sent as: [ghostchat:<sender-name>] <message>

  When you receive a message starting with [ghostchat:...], another agent
  is communicating with you. Reply using ghostchat send whenever a response
  is warranted (questions, requests, actionable info). You can skip replying
  to purely conversational closers like "thanks" or "have a nice day".

INCOMING MESSAGE EXAMPLE
  An incoming message will appear in your conversation like this:

    [ghostchat:swift-falcon] Hey, can you check if the API tests pass?

  When you see this, reply with:

    ghostchat send swift-falcon "Tests are passing, all good!"

COMMANDS
  ghostchat list          List all available terminals with their names
  ghostchat identity      Get or set your terminal's identity metadata
  ghostchat send <target> <message>
                          Send a message to another terminal

  <target> can be:
    - Friendly name (e.g., "swift-falcon")
    - UUID prefix (e.g., "550e8400")

IDENTITY
  Set your role, project, and task so others can see what you're doing:
    ghostchat identity --role builder --project ghostmux --task add-identity
  View your current identity:
    ghostchat identity
  Clear your identity:
    ghostchat identity --clear

EXAMPLES
  ghostchat list
  ghostchat identity --role builder --project ghostmux
  ghostchat send swift-falcon "Hello, I need help with the API"
  ghostchat send 550e8400 "Can you check the test results?"

TIPS
  - Messages are single-line only (newlines are removed)
  - Use quotes around messages with spaces
  - Run 'ghostchat list' to see available online agents
  - Identity fields must not contain spaces (use dashes instead)
"""

private let usage = """
ghostchat - Inter-agent messaging for Claude Code sessions

Usage:
  ghostchat <command> [options]

Commands:
  info                    Show tutorial and your identity
  list                    List all terminals with friendly names
  identity                Get or set your terminal identity
  send <target> <msg>     Send a message to another terminal

Options:
  -h, --help              Show this help
  --json                  Output JSON (for list/identity commands)

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

let identityKeys = ["ghostchat.role", "ghostchat.project", "ghostchat.task"]

func fetchIdentity(client: GhosttyClient, terminalId: String) -> [String: String] {
    guard let meta = try? client.getMetadata(terminalId: terminalId) else {
        return [:]
    }
    var identity: [String: String] = [:]
    for key in identityKeys {
        if let val = meta[key] as? String, !val.isEmpty {
            let shortKey = String(key.dropFirst("ghostchat.".count))
            identity[shortKey] = val
        }
    }
    return identity
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
            let identity = fetchIdentity(client: client, terminalId: terminal.id)
            if !identity.isEmpty {
                entry["identity"] = identity
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

    // Pre-compute columns for alignment
    struct Row {
        let nameCol: String
        let shortId: String
        let cwdShort: String
        let identitySuffix: String
        let focused: Bool
    }

    var rows: [Row] = []
    var maxName = 0
    var maxCwd = 0

    for terminal in terminals {
        let name = NameGenerator.nameFromUUID(terminal.id)
        let isMe = terminal.id == myUUID ? " (you)" : ""
        let nameCol = "\(name)\(isMe)"
        let shortId = NameGenerator.shortUUID(terminal.id)

        let cwdShort: String
        if let cwd = terminal.workingDirectory {
            cwdShort = (cwd as NSString).lastPathComponent
        } else {
            cwdShort = terminal.title
        }

        let identity = fetchIdentity(client: client, terminalId: terminal.id)
        var suffix = ""
        if let role = identity["role"] {
            suffix += "[\(role)]"
        }
        if let task = identity["task"] {
            suffix += suffix.isEmpty ? task : " \(task)"
        }

        maxName = max(maxName, nameCol.count)
        maxCwd = max(maxCwd, cwdShort.count)
        rows.append(Row(nameCol: nameCol, shortId: shortId, cwdShort: cwdShort, identitySuffix: suffix, focused: terminal.focused))
    }

    for row in rows {
        let namePad = row.nameCol.padding(toLength: maxName, withPad: " ", startingAt: 0)
        let cwdPad = row.cwdShort.padding(toLength: maxCwd, withPad: " ", startingAt: 0)
        let focused = row.focused ? " *" : ""
        var line = "\(namePad)  \(row.shortId)  \(cwdPad)"
        if !row.identitySuffix.isEmpty {
            line += "  \(row.identitySuffix)"
        }
        line += focused
        print(line)
    }
}

func handleIdentity(args: [String]) throws {
    guard let myUUID = getMyUUID() else {
        throw GhosttyError.message("$GHOSTTY_SURFACE_UUID not set - are you in a Ghostty terminal?")
    }

    let client = GhosttyClient(socketPath: defaultSocketPath())
    let json = args.contains("--json")

    // --clear: remove all ghostchat.* keys
    if args.contains("--clear") {
        // Get current metadata, rebuild without ghostchat.* keys
        let current = try client.getMetadata(terminalId: myUUID)
        var cleaned: [String: Any] = [:]
        for (key, val) in current where !key.hasPrefix("ghostchat.") {
            cleaned[key] = val
        }
        _ = try client.replaceMetadata(terminalId: myUUID, data: cleaned)
        print("Identity cleared.")
        return
    }

    // Parse --role, --project, --task flags
    var setFields: [String: String] = [:]
    let flagMap = ["--role": "ghostchat.role", "--project": "ghostchat.project", "--task": "ghostchat.task"]

    var i = 0
    while i < args.count {
        if let metaKey = flagMap[args[i]] {
            guard i + 1 < args.count else {
                throw GhosttyError.message("\(args[i]) requires a value")
            }
            let value = args[i + 1]
            if value.contains(" ") || value.contains("\t") {
                throw GhosttyError.message("identity fields must not contain spaces (got \"\(value)\", try \"\(value.replacingOccurrences(of: " ", with: "-"))\")")
            }
            setFields[metaKey] = value
            i += 2
        } else {
            i += 1
        }
    }

    // If setting fields, merge them
    if !setFields.isEmpty {
        _ = try client.mergeMetadata(terminalId: myUUID, data: setFields)
    }

    // Always display current identity
    let identity = fetchIdentity(client: client, terminalId: myUUID)
    let myName = NameGenerator.nameFromUUID(myUUID)

    if json {
        var payload: [String: Any] = [
            "name": myName,
            "id": myUUID
        ]
        if !identity.isEmpty {
            payload["identity"] = identity
        }
        writeJSON(payload)
    } else {
        if identity.isEmpty {
            print("\(myName)  (no identity set)")
        } else {
            var parts: [String] = [myName]
            if let role = identity["role"] { parts.append("[\(role)]") }
            if let project = identity["project"] { parts.append("project:\(project)") }
            if let task = identity["task"] { parts.append("task:\(task)") }
            print(parts.joined(separator: "  "))
        }
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

        case "identity", "id":
            try handleIdentity(args: Array(args.dropFirst()))

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
