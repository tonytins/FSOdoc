/// Where something is in script source, counting from 1.
public struct SourcePosition: Equatable, Sendable {
    public var line: Int
    public var column: Int
}

/// A parsed script: object variables, events in the `default` block, and functions.
struct ScriptSyntax {
    var variables: [(name: String, position: SourcePosition)] = []
    var events: [Function] = []
    var functions: [Function] = []

    struct Function {
        var name: String
        var parameters: [String]
        var body: [ScriptStatement]
        var position: SourcePosition
    }
}

indirect enum ScriptExpression {
    case integer(Int, SourcePosition)
    case boolean(Bool, SourcePosition)
    case variable(String, SourcePosition)
    case unary(String, ScriptExpression, SourcePosition)
    case binary(String, ScriptExpression, ScriptExpression, SourcePosition)
    case call(String, [ScriptExpression], SourcePosition)

    var position: SourcePosition {
        switch self {
        case .integer(_, let position), .boolean(_, let position), .variable(_, let position),
             .unary(_, _, let position), .binary(_, _, _, let position), .call(_, _, let position):
            position
        }
    }
}

indirect enum ScriptStatement {
    case declaration(String, ScriptExpression?, SourcePosition)
    case assignment(String, String, ScriptExpression, SourcePosition)
    case call(String, [ScriptExpression], SourcePosition)
    case conditional(ScriptExpression, [ScriptStatement], [ScriptStatement]?)
    case loop(ScriptExpression, [ScriptStatement])
    case `return`(Bool, SourcePosition)
    case block([ScriptStatement])
}

/// Turns script source into tokens: names, integers, and symbols. `//` and `/* */` are comments.
struct Lexer {
    enum Kind: Equatable { case name, integer, symbol, end }

    struct Token {
        var kind: Kind
        var text: String
        var position: SourcePosition
    }

    static let symbols = ["+=", "-=", "*=", "/=", "%=", "&=", "==", "!=", "<=", ">=", "&&", "||",
                          "{", "}", "(", ")", ";", ",", "=", "+", "-", "*", "/", "%", "&", "<", ">", "!"]

    static func tokens(of source: String) throws(ScriptError) -> [Token] {
        let scalars = Array(source.unicodeScalars)
        var tokens: [Token] = []
        var index = 0, line = 1, lineStart = 0
        func position(_ at: Int) -> SourcePosition { SourcePosition(line: line, column: at - lineStart + 1) }
        func isNameStart(_ scalar: Unicode.Scalar) -> Bool { scalar == "_" || ("a"..."z").contains(scalar) || ("A"..."Z").contains(scalar) }
        func isDigit(_ scalar: Unicode.Scalar) -> Bool { ("0"..."9").contains(scalar) }

        while index < scalars.count {
            let scalar = scalars[index]
            if scalar == "\n" {
                index += 1
                line += 1
                lineStart = index
            } else if scalar == " " || scalar == "\t" || scalar == "\r" {
                index += 1
            } else if scalar == "/", index + 1 < scalars.count, scalars[index + 1] == "/" {
                while index < scalars.count, scalars[index] != "\n" { index += 1 }
            } else if scalar == "/", index + 1 < scalars.count, scalars[index + 1] == "*" {
                let start = position(index)
                index += 2
                while index < scalars.count, !(scalars[index] == "*" && index + 1 < scalars.count && scalars[index + 1] == "/") {
                    if scalars[index] == "\n" {
                        line += 1
                        lineStart = index + 1
                    }
                    index += 1
                }
                guard index < scalars.count else { throw ScriptError(line: start.line, column: start.column, "unfinished comment") }
                index += 2
            } else if isNameStart(scalar) || isDigit(scalar) {
                let start = index
                while index < scalars.count, isNameStart(scalars[index]) || isDigit(scalars[index]) { index += 1 }
                let text = String(String.UnicodeScalarView(scalars[start..<index]))
                tokens.append(Token(kind: isDigit(scalar) ? .integer : .name, text: text, position: position(start)))
            } else {
                let rest = String(String.UnicodeScalarView(scalars[index..<min(index + 2, scalars.count)]))
                guard let symbol = symbols.first(where: { rest.hasPrefix($0) }) else {
                    throw ScriptError(line: line, column: index - lineStart + 1, "unexpected character \(scalar)")
                }
                tokens.append(Token(kind: .symbol, text: symbol, position: position(index)))
                index += symbol.unicodeScalars.count
            }
        }
        tokens.append(Token(kind: .end, text: "end of file", position: position(index)))
        return tokens
    }
}

/// A recursive-descent parser for the LSL-like script language (see ``ScriptCompiler``).
struct Parser {
    private let tokens: [Lexer.Token]
    private var index = 0

    init(_ source: String) throws(ScriptError) {
        tokens = try Lexer.tokens(of: source)
    }

    private var current: Lexer.Token { tokens[index] }

    private func error(_ message: String, at token: Lexer.Token? = nil) -> ScriptError {
        let position = (token ?? current).position
        return ScriptError(line: position.line, column: position.column, message)
    }

    private mutating func advance() -> Lexer.Token {
        defer { if index < tokens.count - 1 { index += 1 } }
        return current
    }

    private mutating func accept(_ text: String) -> Bool {
        guard current.kind != .end, current.text == text else { return false }
        index += 1
        return true
    }

    private mutating func expect(_ text: String) throws(ScriptError) {
        guard accept(text) else { throw error("expected \(text), found \(current.text)") }
    }

    private mutating func name() throws(ScriptError) -> (String, SourcePosition) {
        guard current.kind == .name, !Self.keywords.contains(current.text) else { throw error("expected a name, found \(current.text)") }
        let token = advance()
        return (token.text, token.position)
    }

    static let keywords: Set<String> = ["integer", "default", "if", "else", "while", "return", "TRUE", "FALSE"]

    // MARK: Script

    mutating func script() throws(ScriptError) -> ScriptSyntax {
        var script = ScriptSyntax()
        var sawDefault = false
        while current.kind != .end {
            if accept("integer") {
                let (variable, position) = try name()
                try expect(";")
                script.variables.append((variable, position))
            } else if accept("default") {
                guard !sawDefault else { throw error("only one default block") }
                sawDefault = true
                try expect("{")
                while !accept("}") {
                    guard current.kind != .end else { throw error("unfinished default block") }
                    script.events.append(try function())
                }
            } else {
                script.functions.append(try function())
            }
        }
        guard sawDefault else { throw error("a script needs a default block with its events") }
        return script
    }

    private mutating func function() throws(ScriptError) -> ScriptSyntax.Function {
        let (functionName, position) = try name()
        try expect("(")
        var parameters: [String] = []
        if !accept(")") {
            repeat {
                try expect("integer")
                parameters.append(try name().0)
            } while accept(",")
            try expect(")")
        }
        return ScriptSyntax.Function(name: functionName, parameters: parameters, body: try block(), position: position)
    }

    // MARK: Statements

    private mutating func block() throws(ScriptError) -> [ScriptStatement] {
        try expect("{")
        var statements: [ScriptStatement] = []
        while !accept("}") {
            guard current.kind != .end else { throw error("unfinished block") }
            statements.append(try statement())
        }
        return statements
    }

    private mutating func body() throws(ScriptError) -> [ScriptStatement] {
        current.text == "{" ? try block() : [try statement()]
    }

    private mutating func statement() throws(ScriptError) -> ScriptStatement {
        let start = current
        if accept("integer") {
            let (variable, position) = try name()
            let value = accept("=") ? try expression() : nil
            try expect(";")
            return .declaration(variable, value, position)
        }
        if accept("if") {
            try expect("(")
            let condition = try expression()
            try expect(")")
            let then = try body()
            return .conditional(condition, then, accept("else") ? try body() : nil)
        }
        if accept("while") {
            try expect("(")
            let condition = try expression()
            try expect(")")
            return .loop(condition, try body())
        }
        if accept("return") {
            var value = true
            if accept("FALSE") { value = false } else { _ = accept("TRUE") }
            try expect(";")
            return .return(value, start.position)
        }
        if current.text == "{" { return .block(try block()) }

        let (target, position) = try name()
        if accept("(") {
            let arguments = try argumentList()
            try expect(";")
            return .call(target, arguments, position)
        }
        let operatorToken = advance()
        guard ["=", "+=", "-=", "*=", "/=", "%=", "&="].contains(operatorToken.text) else {
            throw error("expected an assignment or a call", at: operatorToken)
        }
        let value = try expression()
        try expect(";")
        return .assignment(target, operatorToken.text, value, position)
    }

    private mutating func argumentList() throws(ScriptError) -> [ScriptExpression] {
        var arguments: [ScriptExpression] = []
        if accept(")") { return arguments }
        repeat { arguments.append(try expression()) } while accept(",")
        try expect(")")
        return arguments
    }

    // MARK: Expressions, lowest precedence first

    private static let levels: [[String]] = [["||"], ["&&"], ["&"], ["==", "!="], ["<", ">", "<=", ">="], ["+", "-"], ["*", "/", "%"]]

    private mutating func expression(level: Int = 0) throws(ScriptError) -> ScriptExpression {
        guard level < Self.levels.count else { return try unary() }
        var left = try expression(level: level + 1)
        while Self.levels[level].contains(current.text), current.kind == .symbol {
            let token = advance()
            left = .binary(token.text, left, try expression(level: level + 1), token.position)
        }
        return left
    }

    private mutating func unary() throws(ScriptError) -> ScriptExpression {
        let token = current
        if accept("-") || accept("!") { return .unary(token.text, try unary(), token.position) }
        if accept("(") {
            let inner = try expression()
            try expect(")")
            return inner
        }
        if accept("TRUE") { return .boolean(true, token.position) }
        if accept("FALSE") { return .boolean(false, token.position) }
        if token.kind == .integer {
            _ = advance()
            guard let value = Int(token.text), value <= 32_768 else { throw error("\(token.text) is out of range", at: token) }
            return .integer(value, token.position)
        }
        let (variable, position) = try name()
        if accept("(") { return .call(variable, try argumentList(), position) }
        return .variable(variable, position)
    }
}
