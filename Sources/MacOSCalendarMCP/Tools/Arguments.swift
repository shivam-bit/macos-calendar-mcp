import Foundation
import MCP

public struct Arguments: Sendable {
    private let values: [String: Value]

    public init(_ values: [String: Value]) { self.values = values }

    func string(_ key: String) throws -> String {
        guard let value = try optionalString(key), !value.isEmpty else { throw ToolError.invalidInput("\(key) is required") }
        return value
    }

    func optionalString(_ key: String) throws -> String? {
        guard let value = values[key], !value.isNull else { return nil }
        guard let text = value.stringValue else { throw ToolError.invalidInput("\(key) must be a string") }
        return text
    }

    func date(_ key: String) throws -> Date {
        guard let date = try optionalDate(key) else { throw ToolError.invalidInput("\(key) is required") }
        return date
    }

    func optionalDate(_ key: String) throws -> Date? {
        guard let text = try optionalString(key) else { return nil }
        guard let date = Dates.parse(text) else { throw ToolError.invalidInput("\(key) is not an ISO-8601 date: \(text)") }
        return date
    }

    func optionalBool(_ key: String) throws -> Bool? {
        guard let value = values[key], !value.isNull else { return nil }
        guard let flag = value.boolValue else { throw ToolError.invalidInput("\(key) must be true or false") }
        return flag
    }

    func optionalInt(_ key: String) throws -> Int? {
        guard let value = values[key], !value.isNull else { return nil }
        guard let number = value.intValue ?? value.doubleValue.flatMap({ Int(exactly: $0) }) else { throw ToolError.invalidInput("\(key) must be a whole number") }
        return number
    }

    func optionalStrings(_ key: String) throws -> [String]? {
        guard let value = values[key], !value.isNull else { return nil }
        let items = value.arrayValue?.map(\.stringValue)
        guard let items, items.allSatisfy({ $0 != nil }) else { throw ToolError.invalidInput("\(key) must be a list of strings") }
        return items.compactMap { $0 }
    }
}
