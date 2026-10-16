/// A SimAntics variable: a scope and the data that picks a value in it.
///
/// FreeSO calls these the owner and the data. The data is usually an index (temp 3, attribute
/// 7) and for the literal scope it's the value itself. Operands store scopes in 8 or 16 bits,
/// so the raw scope keeps 16; one with no ``VariableScope`` fails when used, as in FreeSO.
public struct Variable: Sendable, Hashable, CustomStringConvertible {
    public var rawScope: UInt16
    public var data: Int16

    public init(rawScope: UInt16, data: Int16) {
        self.rawScope = rawScope
        self.data = data
    }

    public init(_ scope: VariableScope, _ data: Int16) {
        self.init(rawScope: UInt16(scope.rawValue), data: data)
    }

    public static func literal(_ value: Int16) -> Variable {
        Variable(.literal, value)
    }

    /// The scope, or `nil` for a raw value with none.
    public var scope: VariableScope? {
        UInt8(exactly: rawScope).flatMap(VariableScope.init(rawValue:))
    }

    public var description: String {
        "\(scope.map { "\($0)" } ?? "scope\(rawScope)") \(data)"
    }
}

// MARK: - Reading and writing

extension StackFrame {
    /// A variable's value, as FreeSO's `VMMemory.GetVariable` reads it.
    public func value(of variable: Variable) throws(SimAnticsError) -> Int16 {
        try VMMemory.value(of: variable, in: self)
    }

    /// Sets a variable, as `VMMemory.SetVariable` does. Returns `false` for scopes that can't be set.
    @discardableResult
    public func setValue(_ value: Int16, of variable: Variable) throws(SimAnticsError) -> Bool {
        try VMMemory.setValue(value, of: variable, in: self)
    }

    /// A variable as a 32-bit value; only `TempXL` holds more than 16 bits (`GetBigVariable`).
    public func bigValue(of variable: Variable) throws(SimAnticsError) -> Int32 {
        try VMMemory.bigValue(of: variable, in: self)
    }

    /// Sets a variable from a 32-bit value, truncated for 16-bit scopes (`SetBigVariable`).
    @discardableResult
    public func setBigValue(_ value: Int32, of variable: Variable) throws(SimAnticsError) -> Bool {
        try VMMemory.setBigValue(value, of: variable, in: self)
    }
}
