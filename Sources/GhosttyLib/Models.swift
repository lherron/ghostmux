import Foundation

public struct Terminal {
    public let id: String
    public let title: String
    public let workingDirectory: String?
    public let focused: Bool
    public let columns: Int?
    public let rows: Int?
    public let cellWidth: Int?
    public let cellHeight: Int?

    public init(
        id: String,
        title: String,
        workingDirectory: String? = nil,
        focused: Bool = false,
        columns: Int? = nil,
        rows: Int? = nil,
        cellWidth: Int? = nil,
        cellHeight: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.workingDirectory = workingDirectory
        self.focused = focused
        self.columns = columns
        self.rows = rows
        self.cellWidth = cellWidth
        self.cellHeight = cellHeight
    }
}

public struct CreateTerminalRequest {
    public var location: String?
    public var workingDirectory: String?
    public var command: String?
    public var env: [String: String]?
    public var parent: String?

    public init(
        location: String? = nil,
        workingDirectory: String? = nil,
        command: String? = nil,
        env: [String: String]? = nil,
        parent: String? = nil
    ) {
        self.location = location
        self.workingDirectory = workingDirectory
        self.command = command
        self.env = env
        self.parent = parent
    }

    public func toBody() -> [String: Any] {
        var body: [String: Any] = [:]
        if let location {
            body["location"] = location
        }
        if let workingDirectory {
            body["working_directory"] = workingDirectory
        }
        if let command {
            body["command"] = command
        }
        if let env {
            body["env"] = env
        }
        if let parent {
            body["parent"] = parent
        }
        return body
    }
}

public struct KeyStroke {
    public let key: String
    public let mods: [String]
    public let text: String?
    public let unshiftedCodepoint: UInt32

    public init(key: String, mods: [String], text: String?, unshiftedCodepoint: UInt32) {
        self.key = key
        self.mods = mods
        self.text = text
        self.unshiftedCodepoint = unshiftedCodepoint
    }
}

extension Terminal {
    public func toJsonDict() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "name": NameGenerator.nameFromUUID(id),
            "short_id": NameGenerator.shortUUID(id),
            "title": title,
            "focused": focused,
        ]
        if let workingDirectory {
            dict["working_directory"] = workingDirectory
        }
        if let columns {
            dict["columns"] = columns
        }
        if let rows {
            dict["rows"] = rows
        }
        if let cellWidth {
            dict["cell_width"] = cellWidth
        }
        if let cellHeight {
            dict["cell_height"] = cellHeight
        }
        return dict
    }
}
