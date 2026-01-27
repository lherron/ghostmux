import Foundation

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
    if let env = ProcessInfo.processInfo.environment["GHOSTTY_API_SOCKET"], !env.isEmpty {
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
