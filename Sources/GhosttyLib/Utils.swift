import Foundation

/// Resolve an environment variable, preferring tmux session env when inside tmux.
/// When $TMUX is set, queries `tmux show-environment` for the fresh value
/// (updated on attach via update-environment). Inside tmux, process-inherited
/// GHOSTTY_* vars are stale — only tmux session env is authoritative.
/// Outside tmux, falls back to process env (current behavior).
public func resolveEnv(_ name: String) -> String? {
    if ProcessInfo.processInfo.environment["TMUX"] != nil {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = ["tmux", "show-environment", name]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return nil
        }
        guard proc.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let line = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              let eqIdx = line.firstIndex(of: "=") else {
            return nil
        }
        let value = String(line[line.index(after: eqIdx)...])
        return value.isEmpty ? nil : value
    }
    return ProcessInfo.processInfo.environment[name]
}

public func resolveTarget(_ target: String, terminals: [Terminal]) -> Terminal? {
    let lowerTarget = target.lowercased()

    if let exactId = terminals.first(where: { $0.id == target }) {
        return exactId
    }

    if let exactTitle = terminals.first(where: { $0.title.lowercased() == lowerTarget }) {
        return exactTitle
    }

    if let partial = terminals.first(where: { $0.title.lowercased().contains(lowerTarget) }) {
        return partial
    }

    if let prefix = terminals.first(where: { $0.id.hasPrefix(target) }) {
        return prefix
    }

    return nil
}

public func defaultSocketPath() -> String {
    if let env = resolveEnv("GHOSTTY_API_SOCKET"), !env.isEmpty {
        return env
    }

    let home = FileManager.default.homeDirectoryForCurrentUser
    return home.appendingPathComponent("Library/Application Support/Ghostty/api.sock").path
}

public func writeStdout(_ text: String) {
    guard let data = text.data(using: .utf8) else {
        return
    }
    FileHandle.standardOutput.write(data)
}

public func writeJSON(_ object: Any) {
    do {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        if let text = String(data: data, encoding: .utf8) {
            print(text)
            return
        }
    } catch {
        // fall through to plain print
    }
    print("{}")
}
