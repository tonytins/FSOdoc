import Foundation
import SimAntics
import TSOFiles

/// A text form of BHAV routines that converts back to the same routines.
///
/// Each routine starts with a header line, and each instruction follows on its own line:
///
///     bhav 4096 "main" version 0x8002 type 0 arguments 4 locals 2 flags 0x0000
///       0: expression temps 0 := literal 5 -> 1 / return-false
///       1: call 4097 1 0 0 0 -> return-true / return-false
///       2: primitive 44 0a00000100000000 -> 2 / 3
///
/// Expression (opcode 2) is written as its two sides and operator; calls (opcodes 256 and
/// up) as the opcode and four arguments; any other primitive as its opcode and 8 operand
/// bytes in hex. Branch targets are instruction numbers or `return-true` (254),
/// `return-false` (255), and `follow` (253). `#` starts a comment.
public enum Assembly {
    // MARK: Disassembly

    /// Routines as text.
    public static func text(of routines: [BHAV]) -> String {
        routines.map(text(of:)).joined(separator: "\n")
    }

    public static func text(of routine: BHAV) -> String {
        var lines = ["bhav \(routine.id) \(quoted(routine.label)) version 0x\(hex(routine.version)) type \(routine.type) "
            + "arguments \(routine.argumentCount) locals \(routine.localCount) flags 0x\(hex(routine.flags))"]
        for (index, instruction) in routine.instructions.enumerated() {
            lines.append("  \(index): \(body(of: instruction)) -> \(target(instruction.truePointer)) / \(target(instruction.falsePointer))")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func body(of instruction: BHAV.Instruction) -> String {
        let bytes = [UInt8](instruction.operand.prefix(8)) + [UInt8](repeating: 0, count: max(0, 8 - instruction.operand.count))
        if instruction.opcode >= 256 {
            return "call \(instruction.opcode) " + SubroutineOperand(bytes: bytes).arguments.map(String.init).joined(separator: " ")
        }
        if instruction.opcode == Primitives.Expression.opcode, instruction.operand.count <= 8 {
            let operand = Primitives.Expression.Operand(bytes: bytes)
            // Only a form that encodes back to the same bytes may be written as an expression.
            if operand.encoded() == bytes {
                var text = "expression \(operand.lhs) \(operatorName(operand.rawOperator)) \(operand.rhs)"
                if operand.isSigned != 0 { text += " signed \(operand.isSigned)" }
                return text
            }
        }
        return "primitive \(instruction.opcode) " + [UInt8](instruction.operand).map { hex($0) }.joined()
    }

    // MARK: Assembly

    /// Routines from text.
    ///
    /// - Throws: ``ScriptError`` for malformed lines, unknown names, instruction numbers out of
    ///   order, or values out of range.
    public static func routines(from text: String) throws(ScriptError) -> [BHAV] {
        var routines: [BHAV] = []
        var header: (id: UInt16, label: String, version: UInt16, type: UInt8, arguments: UInt8, locals: UInt16, flags: UInt16)?
        var instructions: [BHAV.Instruction] = []
        func finish() {
            guard let header else { return }
            routines.append(BHAV(id: header.id, label: header.label, version: header.version, type: header.type,
                                 argumentCount: header.arguments, localCount: header.locals, flags: header.flags,
                                 instructions: instructions))
            instructions = []
        }
        for (lineIndex, rawLine) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            var line = LineReader(String(rawLine), number: lineIndex + 1)
            guard let first = try line.next() else { continue }
            if first == "bhav" {
                finish()
                header = (try line.integer(UInt16.self), try line.string(), try line.keyword("version", UInt16.self),
                          try line.keyword("type", UInt8.self), try line.keyword("arguments", UInt8.self),
                          try line.keyword("locals", UInt16.self), try line.keyword("flags", UInt16.self))
                try line.end()
                continue
            }
            guard header != nil else { throw line.error("an instruction outside a bhav") }
            guard first == "\(instructions.count):" else { throw line.error("expected instruction \(instructions.count):") }
            instructions.append(try instruction(&line))
        }
        finish()
        return routines
    }

    private static func instruction(_ line: inout LineReader) throws(ScriptError) -> BHAV.Instruction {
        let opcode: UInt16
        let operand: [UInt8]
        switch try line.required("an instruction") {
        case "expression":
            let lhsScope = try scope(try line.required("a scope"), line)
            let lhsData = try line.integer(Int16.self)
            let rawOperator = try operatorValue(try line.required("an operator"), line)
            let rhsScope = try scope(try line.required("a scope"), line)
            let rhsData = try line.integer(Int16.self)
            var isSigned: UInt8 = 0
            if try line.peek() == "signed" {
                _ = try line.next()
                isSigned = try line.integer(UInt8.self)
            }
            opcode = UInt16(Primitives.Expression.opcode)
            operand = Primitives.Expression.Operand(Variable(rawScope: UInt16(lhsScope), data: lhsData), rawOperator,
                                                    Variable(rawScope: UInt16(rhsScope), data: rhsData), isSigned: isSigned).encoded()
        case "call":
            opcode = try line.integer(UInt16.self)
            guard opcode >= 256 else { throw line.error("a call's opcode is 256 or more") }
            operand = SubroutineOperand(arguments: [try line.integer(Int16.self), try line.integer(Int16.self),
                                                    try line.integer(Int16.self), try line.integer(Int16.self)]).encoded()
        case "primitive":
            opcode = try line.integer(UInt16.self)
            let digits = try line.required("operand bytes")
            guard digits.count % 2 == 0, digits.count <= 16, let bytes = bytes(fromHex: digits) else {
                throw line.error("operand bytes must be up to 8 bytes of hex")
            }
            operand = bytes
        case let other:
            throw line.error("unknown instruction \(other)")
        }
        guard try line.next() == "->" else { throw line.error("expected -> and the branch targets") }
        let truePointer = try target(try line.required("a true target"), line)
        guard try line.next() == "/" else { throw line.error("expected / between the branch targets") }
        let falsePointer = try target(try line.required("a false target"), line)
        try line.end()
        return BHAV.Instruction(opcode: opcode, truePointer: truePointer, falsePointer: falsePointer, operand: Data(operand))
    }

    // MARK: Names

    static let operatorNames: [UInt8: String] = [
        0: ">", 1: "<", 2: "==", 3: "+=", 4: "-=", 5: ":=", 6: "*=", 7: "/=", 8: "flag?", 9: "flag+", 10: "flag-",
        11: "++<", 12: "%=", 13: "&=", 14: ">=", 15: "<=", 16: "!=", 17: "-->", 18: "push", 19: "pop",
    ]

    static func operatorName(_ raw: UInt8) -> String { operatorNames[raw] ?? "op\(raw)" }

    private static func operatorValue(_ token: String, _ line: LineReader) throws(ScriptError) -> UInt8 {
        if let match = operatorNames.first(where: { $0.value == token }) { return match.key }
        if token.hasPrefix("op"), let raw = UInt8(token.dropFirst(2)) { return raw }
        throw line.error("unknown operator \(token)")
    }

    private static func scope(_ token: String, _ line: LineReader) throws(ScriptError) -> UInt8 {
        if let match = VariableScope.allCases.first(where: { "\($0)" == token }) { return match.rawValue }
        if token.hasPrefix("scope"), let raw = UInt8(token.dropFirst(5)) { return raw }
        throw line.error("unknown scope \(token)")
    }

    private static func target(_ pointer: UInt8) -> String {
        switch pointer {
        case 253: "follow"
        case 254: "return-true"
        case 255: "return-false"
        default: "\(pointer)"
        }
    }

    private static func target(_ token: String, _ line: LineReader) throws(ScriptError) -> UInt8 {
        switch token {
        case "follow": return 253
        case "return-true": return 254
        case "return-false": return 255
        default:
            guard let pointer = UInt8(token), pointer < 253 else { throw line.error("a branch target is 0 to 252, return-true, return-false, or follow") }
            return pointer
        }
    }

    // MARK: Text helpers

    private static func hex<Value: FixedWidthInteger>(_ value: Value) -> String {
        let digits = String(value, radix: 16)
        return String(repeating: "0", count: max(0, Value.bitWidth / 4 - digits.count)) + digits
    }

    private static func bytes(fromHex text: String) -> [UInt8]? {
        var bytes: [UInt8] = []
        var index = text.startIndex
        while index < text.endIndex {
            let next = text.index(index, offsetBy: 2)
            guard let byte = UInt8(text[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        return bytes
    }

    /// A label in quotes, with `\"`, `\\`, and `\u{…}` for anything outside printable ASCII.
    static func quoted(_ text: String) -> String {
        var result = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case " "..."~": result.unicodeScalars.append(scalar)
            default: result += "\\u{\(String(scalar.value, radix: 16))}"
            }
        }
        return result + "\""
    }
}

/// Splits one line of assembly into tokens: words, and labels in quotes.
private struct LineReader {
    private let scalars: [Unicode.Scalar]
    private var position = 0
    let number: Int

    init(_ text: String, number: Int) {
        scalars = Array(text.unicodeScalars)
        self.number = number
    }

    func error(_ message: String) -> ScriptError { ScriptError(line: number, column: position + 1, message) }

    private mutating func skipSpaces() {
        while position < scalars.count, scalars[position] == " " || scalars[position] == "\t" { position += 1 }
    }

    mutating func next() throws(ScriptError) -> String? {
        skipSpaces()
        guard position < scalars.count, scalars[position] != "#" else { return nil }
        guard scalars[position] != "\"" else { return try quoted() }
        var token = String.UnicodeScalarView()
        while position < scalars.count, scalars[position] != " ", scalars[position] != "\t" {
            token.append(scalars[position])
            position += 1
        }
        return String(token)
    }

    mutating func peek() throws(ScriptError) -> String? {
        var copy = self
        return try copy.next()
    }

    mutating func required(_ what: String) throws(ScriptError) -> String {
        guard let token = try next() else { throw error("expected \(what)") }
        return token
    }

    mutating func integer<Value: FixedWidthInteger>(_ type: Value.Type) throws(ScriptError) -> Value {
        let token = try required("a number")
        let value = token.hasPrefix("0x") ? Value(token.dropFirst(2), radix: 16) : Value(token)
        guard let value else { throw error("\(token) isn't a number from \(Value.min) to \(Value.max)") }
        return value
    }

    mutating func keyword<Value: FixedWidthInteger>(_ keyword: String, _ type: Value.Type) throws(ScriptError) -> Value {
        guard try next() == keyword else { throw error("expected \(keyword)") }
        return try integer(type)
    }

    mutating func string() throws(ScriptError) -> String {
        skipSpaces()
        guard position < scalars.count, scalars[position] == "\"" else { throw error("expected a label in quotes") }
        return try quoted()
    }

    mutating func end() throws(ScriptError) {
        if let extra = try next() { throw error("unexpected \(extra)") }
    }

    private mutating func quoted() throws(ScriptError) -> String {
        position += 1
        var result = String.UnicodeScalarView()
        while position < scalars.count {
            let scalar = scalars[position]
            position += 1
            switch scalar {
            case "\"":
                return String(result)
            case "\\":
                guard position < scalars.count else { throw error("unfinished escape") }
                let escaped = scalars[position]
                position += 1
                if escaped == "u" {
                    guard position < scalars.count, scalars[position] == "{",
                          let close = scalars[position...].firstIndex(of: "}"),
                          let value = UInt32(String(String.UnicodeScalarView(scalars[(position + 1)..<close])), radix: 16),
                          let decoded = Unicode.Scalar(value) else { throw error("bad \\u{} escape") }
                    result.append(decoded)
                    position = close + 1
                } else {
                    result.append(escaped)
                }
            default:
                result.append(scalar)
            }
        }
        throw error("unfinished label")
    }
}
