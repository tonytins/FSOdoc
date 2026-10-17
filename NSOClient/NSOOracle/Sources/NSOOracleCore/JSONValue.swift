import Foundation

/// A decoded JSON value that keeps integers, booleans, and strings apart, as `System.Text.Json`
/// does, so a request is validated the way `fso-oracle` validates it (`true` isn't the number 1).
enum JSONValue: Decodable, Equatable {
    case null
    case bool(Bool)
    case integer(Int64)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue], keys: [String])

    init(from decoder: any Decoder) throws {
        if var array = try? decoder.unkeyedContainer() {
            var items: [JSONValue] = []
            while !array.isAtEnd { items.append(try array.decode(JSONValue.self)) }
            self = .array(items)
            return
        }
        if let object = try? decoder.container(keyedBy: Key.self) {
            var values: [String: JSONValue] = [:]
            for key in object.allKeys { values[key.stringValue] = try object.decode(JSONValue.self, forKey: key) }
            self = .object(values, keys: object.allKeys.map(\.stringValue))
            return
        }
        let value = try decoder.singleValueContainer()
        if value.decodeNil() {
            self = .null
        } else if let flag = try? value.decode(Bool.self) {
            self = .bool(flag)
        } else if let integer = try? value.decode(Int64.self) {
            self = .integer(integer)
        } else if let number = try? value.decode(Double.self) {
            self = .number(number)
        } else {
            self = .string(try value.decode(String.self))
        }
    }

    /// Parses one line of JSON.
    static func parse(_ text: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
    }

    /// The value as `JSONSerialization` writes it.
    var foundationValue: Any {
        switch self {
        case .null: NSNull()
        case .bool(let flag): flag
        case .integer(let integer): integer
        case .number(let number): number
        case .string(let text): text
        case .array(let items): items.map(\.foundationValue)
        case .object(let values, _): values.mapValues(\.foundationValue)
        }
    }

    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }
}
