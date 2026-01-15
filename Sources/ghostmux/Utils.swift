import Foundation

func resolveTarget(_ target: String, terminals: [Terminal]) -> Terminal? {
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

func defaultSocketPath() -> String {
    if let env = ProcessInfo.processInfo.environment["GHOSTTY_API_SOCKET"], !env.isEmpty {
        return env
    }

    let home = FileManager.default.homeDirectoryForCurrentUser
    return home.appendingPathComponent("Library/Application Support/Ghostty/api.sock").path
}

func writeStdout(_ text: String) {
    guard let data = text.data(using: .utf8) else {
        return
    }
    FileHandle.standardOutput.write(data)
}
