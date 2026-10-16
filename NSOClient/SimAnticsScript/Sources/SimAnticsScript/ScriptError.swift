/// An error in assembly or script source, with where it was found.
public struct ScriptError: Error, Equatable, Sendable, CustomStringConvertible {
    public var line: Int
    public var column: Int
    public var message: String

    public init(line: Int, column: Int, _ message: String) {
        self.line = line
        self.column = column
        self.message = message
    }

    public var description: String { "\(line):\(column): \(message)" }
}
