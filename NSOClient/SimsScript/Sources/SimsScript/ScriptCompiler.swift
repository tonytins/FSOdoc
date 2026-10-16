import Foundation
import SimAntics
import TSOFiles

/// An object compiled from script: its routines and the function table that runs them.
public struct CompiledObject: Sendable {
    /// Private routines, from ID 4096: the events in order, then the functions.
    public var routines: [BHAV]
    /// Each entry point's routine ID, or 0, indexed like ``Entity/EntryPointIndex``.
    public var entryPoints: [UInt16]
    /// The object variables, in attribute order.
    public var attributes: [String]

    /// The function table as `OBJf` chunk data (version 0), for an `OBJD` that uses one.
    public func functionTableData() -> Data {
        var bytes = Data()
        func append<Value: FixedWidthInteger>(_ value: Value) {
            withUnsafeBytes(of: value.littleEndian) { bytes.append(contentsOf: $0) }
        }
        append(UInt32(0))
        append(UInt32(0))
        bytes.append(contentsOf: Array("fJBO".utf8))
        append(UInt32(entryPoints.count))
        for routine in entryPoints {
            append(UInt16(0))
            append(routine)
        }
        return bytes
    }

    /// The routines in ``Assembly`` form.
    public var assembly: String { Assembly.text(of: routines) }
}

/// Compiles an LSL-like script into SimAntics routines. A proof of concept.
///
/// ```
/// integer count;                    // object variables are attributes, in order
///
/// add(integer amount) {             // functions are private routines (up to 4 parameters)
///     count += amount;
/// }
///
/// default {                         // events are entry points: initialize, main, cleanup, ...
///     initialize() { count = 0; }
///     main() {
///         integer i = 3;            // locals
///         while (i > 0) { add(2); i -= 1; }
///         if (count >= 6 && !(count == 7)) { return TRUE; }
///     }
/// }
/// ```
///
/// Values are 16-bit integers with SimAntics arithmetic: it wraps, dividing by zero gives
/// -1, and a remainder by zero leaves the value. Operators: `+ - * / % &`, comparisons, and
/// in conditions `&& || !`. A function returns only true or false (`return TRUE;`,
/// `return FALSE;`, or falling off the end, which returns true), so a call can be a condition.
/// Intermediate values go in extra locals; arguments that aren't plain numbers are passed
/// through temps 0 to 3.
public enum ScriptCompiler {
    public static func compile(_ source: String) throws(ScriptError) -> CompiledObject {
        var parser = try Parser(source)
        let script = try parser.script()

        var attributes: [String: Int16] = [:]
        for (index, variable) in script.variables.enumerated() {
            guard attributes[variable.name] == nil else { throw error("\(variable.name) is declared twice", variable.position) }
            attributes[variable.name] = Int16(index)
        }

        var routineIDs: [String: (id: UInt16, parameters: Int)] = [:]
        var entryPoints = [UInt16](repeating: 0, count: 33)
        let all = script.events + script.functions
        guard all.count <= 4096 else { throw ScriptError(line: 1, column: 1, "too many routines") }
        for (offset, function) in all.enumerated() {
            let id = UInt16(4096 + offset)
            if offset < script.events.count {
                guard let entry = Entity.EntryPointIndex.allNames[function.name] else {
                    throw error("\(function.name) isn't an event; events are \(Entity.EntryPointIndex.allNames.keys.sorted().joined(separator: ", "))",
                                function.position)
                }
                guard function.parameters.isEmpty else { throw error("events take no parameters", function.position) }
                guard entryPoints[entry.rawValue] == 0 else { throw error("\(function.name) is handled twice", function.position) }
                entryPoints[entry.rawValue] = id
            } else {
                guard routineIDs[function.name] == nil else { throw error("\(function.name) is defined twice", function.position) }
                guard function.parameters.count <= 4 else { throw error("a function takes at most 4 parameters", function.position) }
                routineIDs[function.name] = (id, function.parameters.count)
            }
        }

        var routines: [BHAV] = []
        for (offset, function) in all.enumerated() {
            var generator = try RoutineGenerator(function: function, attributes: attributes, routines: routineIDs)
            routines.append(try generator.generate(id: UInt16(4096 + offset)))
        }
        return CompiledObject(routines: routines, entryPoints: entryPoints, attributes: script.variables.map(\.name))
    }

    static func error(_ message: String, _ position: SourcePosition) -> ScriptError {
        ScriptError(line: position.line, column: position.column, message)
    }
}

extension Entity.EntryPointIndex {
    /// Entry points by their event names in scripts.
    static let allNames: [String: Entity.EntryPointIndex] = {
        var names: [String: Entity.EntryPointIndex] = [:]
        var index = 0
        while let entry = Entity.EntryPointIndex(rawValue: index) {
            names["\(entry)"] = entry
            index += 1
        }
        return names
    }()
}

/// A branch of an emitted instruction: its index, and whether it's the true branch.
private struct Edge {
    var instruction: Int
    var isTrue: Bool
}

/// A place in the routine that branches can target before it's known.
private final class Label {
    /// The instruction index, once placed.
    var position: Int?
    /// Branches waiting for the label to be placed.
    var edges: [Edge] = []
}

/// Generates one routine. SimAntics has no jump instruction, so control flow is made by
/// pointing branches: "fall-through" branches go to the next instruction emitted.
private struct RoutineGenerator {
    private let function: ScriptSyntax.Function
    private let attributes: [String: Int16]
    private let routines: [String: (id: UInt16, parameters: Int)]
    private var locals: [String: Int16] = [:]
    private var hiddenBase: Int16 = 0
    private var hiddenInUse: Int16 = 0
    private var hiddenMaximum: Int16 = 0

    private var instructions: [(opcode: UInt16, operand: [UInt8], targets: [UInt8?])] = []
    private var fallThrough: [Edge] = []

    init(function: ScriptSyntax.Function, attributes: [String: Int16],
         routines: [String: (id: UInt16, parameters: Int)]) throws(ScriptError) {
        self.function = function
        self.attributes = attributes
        self.routines = routines
        var names = Set(function.parameters)
        guard names.count == function.parameters.count else { throw ScriptCompiler.error("a parameter is named twice", function.position) }
        // Locals are numbered before the body is generated, so extra locals can follow them.
        func declare(_ statements: [ScriptStatement]) throws(ScriptError) {
            for statement in statements {
                switch statement {
                case .declaration(let name, _, let position):
                    guard !names.contains(name) else { throw ScriptCompiler.error("\(name) is declared twice", position) }
                    names.insert(name)
                    locals[name] = Int16(locals.count)
                case .conditional(_, let then, let otherwise):
                    try declare(then)
                    try declare(otherwise ?? [])
                case .loop(_, let body), .block(let body):
                    try declare(body)
                default:
                    break
                }
            }
        }
        try declare(function.body)
        hiddenBase = Int16(locals.count)
    }

    mutating func generate(id: UInt16) throws(ScriptError) -> BHAV {
        try statements(function.body)
        resolve(fallThrough, to: 254)
        fallThrough = []
        guard instructions.count <= 253 else {
            throw ScriptCompiler.error("\(function.name) needs \(instructions.count) instructions; a routine holds at most 253", function.position)
        }
        let localCount = UInt16(hiddenBase + hiddenMaximum)
        return BHAV(id: id, label: function.name, version: 0x8002, type: 0, argumentCount: UInt8(function.parameters.count),
                    localCount: localCount, flags: 0, instructions: instructions.map { instruction in
                        BHAV.Instruction(opcode: instruction.opcode, truePointer: instruction.targets[0] ?? 254,
                                         falsePointer: instruction.targets[1] ?? 254, operand: Data(instruction.operand))
                    })
    }

    // MARK: Emitting

    /// Emits an instruction; pending fall-through branches point to it. Its own branches are returned.
    private mutating func emit(_ opcode: UInt16, _ operand: [UInt8]) -> (Edge, Edge) {
        let index = instructions.count
        resolve(fallThrough, to: index)
        fallThrough = []
        instructions.append((opcode, operand, [nil, nil]))
        return (Edge(instruction: index, isTrue: true), Edge(instruction: index, isTrue: false))
    }

    /// Emits an instruction whose branches both continue to the next one.
    private mutating func emitStep(_ opcode: UInt16, _ operand: [UInt8]) {
        let (onTrue, onFalse) = emit(opcode, operand)
        fallThrough = [onTrue, onFalse]
    }

    private mutating func expression(_ target: Variable, _ operatorValue: UInt8, _ source: Variable) -> [UInt8] {
        Primitives.Expression.Operand(target, operatorValue, source).encoded()
    }

    /// Points branches at an instruction index or a return (254, 255). Routines over 253
    /// instructions are rejected when built, so an index here always fits.
    private mutating func resolve(_ edges: [Edge], to pointer: Int) {
        for edge in edges { instructions[edge.instruction].targets[edge.isTrue ? 0 : 1] = UInt8(truncatingIfNeeded: pointer) }
    }

    /// A routine starts at instruction 0, so a jump or return before the first instruction
    /// needs an instruction to start from: a test that is always true.
    private mutating func ensureEntryInstruction() {
        if instructions.isEmpty { emitStep(2, expression(.literal(0), 2, .literal(0))) }
    }

    private mutating func attach(_ edge: Edge, to label: Label) {
        if let position = label.position, position < instructions.count {
            resolve([edge], to: position)
        } else if label.position != nil {
            fallThrough.append(edge) // placed here: the next instruction
        } else {
            label.edges.append(edge)
        }
    }

    /// Makes the next instruction the label's target.
    private mutating func place(_ label: Label) {
        label.position = instructions.count
        fallThrough += label.edges
        label.edges = []
    }

    /// Sends the current fall-through branches to a label; the code after is unreachable until a label.
    private mutating func jump(to label: Label, at position: SourcePosition) throws(ScriptError) {
        ensureEntryInstruction()
        if let target = label.position, target == instructions.count {
            throw ScriptCompiler.error("this loop has no instructions to repeat", position)
        }
        let edges = fallThrough
        fallThrough = []
        for edge in edges { attach(edge, to: label) }
    }

    private mutating func returnFromHere(_ value: Bool) {
        ensureEntryInstruction()
        for edge in fallThrough { instructions[edge.instruction].targets[edge.isTrue ? 0 : 1] = value ? 254 : 255 }
        fallThrough = []
    }

    // MARK: Statements

    private mutating func statements(_ list: [ScriptStatement]) throws(ScriptError) {
        for statement in list { try self.statement(statement) }
    }

    private mutating func statement(_ statement: ScriptStatement) throws(ScriptError) {
        defer { hiddenInUse = 0 }
        switch statement {
        case .declaration(let name, let value, _):
            if let value { try assign(Variable(.local, locals[name] ?? 0), value) }
        case .assignment(let name, let operatorText, let value, let position):
            let target = try variable(name, position)
            if operatorText == "=" {
                try assign(target, value)
            } else {
                let source = try operand(value)
                emitStep(2, expression(target, Self.compoundOperators[operatorText] ?? 5, source))
            }
        case .call(let name, let arguments, let position):
            let (onTrue, onFalse) = try call(name, arguments, position)
            fallThrough += [onTrue, onFalse]
        case .conditional(let condition, let then, let otherwise):
            let thenLabel = Label(), elseLabel = Label(), endLabel = Label()
            try self.condition(condition, onTrue: thenLabel, onFalse: elseLabel)
            place(thenLabel)
            try statements(then)
            if let otherwise {
                try jump(to: endLabel, at: condition.position)
                place(elseLabel)
                try statements(otherwise)
            } else {
                place(elseLabel)
            }
            place(endLabel)
        case .loop(let condition, let body):
            let start = Label(), bodyLabel = Label(), end = Label()
            place(start)
            try self.condition(condition, onTrue: bodyLabel, onFalse: end)
            place(bodyLabel)
            try statements(body)
            try jump(to: start, at: condition.position)
            place(end)
        case .return(let value, _):
            returnFromHere(value)
        case .block(let body):
            try statements(body)
        }
    }

    static let compoundOperators: [String: UInt8] = ["+=": 3, "-=": 4, "*=": 6, "/=": 7, "%=": 12, "&=": 13]
    static let arithmeticOperators: [String: UInt8] = ["+": 3, "-": 4, "*": 6, "/": 7, "%": 12, "&": 13]
    static let comparisonOperators: [String: UInt8] = [">": 0, "<": 1, "==": 2, ">=": 14, "<=": 15, "!=": 16]

    // MARK: Values

    private func variable(_ name: String, _ position: SourcePosition) throws(ScriptError) -> Variable {
        if let index = locals[name] { return Variable(.local, index) }
        if let index = function.parameters.firstIndex(of: name) { return Variable(.parameters, Int16(index)) }
        if let index = attributes[name] { return Variable(.myObjectAttributes, index) }
        throw ScriptCompiler.error("\(name) isn't declared", position)
    }

    /// A plain number or variable, if the expression is one.
    private func leaf(_ value: ScriptExpression) throws(ScriptError) -> Variable? {
        switch value {
        case .integer(let number, let position):
            guard number <= 32_767 else { throw ScriptCompiler.error("\(number) is out of range", position) }
            return .literal(Int16(number))
        case .unary("-", .integer(let number, _), _):
            return .literal(Int16(truncatingIfNeeded: -number))
        case .variable(let name, let position):
            return try variable(name, position)
        default:
            return nil
        }
    }

    private mutating func hidden() -> Variable {
        let operand = Variable(.local, hiddenBase + hiddenInUse)
        hiddenInUse += 1
        hiddenMaximum = max(hiddenMaximum, hiddenInUse)
        return operand
    }

    /// The expression's value as an operand, computed into an extra local if needed.
    private mutating func operand(_ value: ScriptExpression) throws(ScriptError) -> Variable {
        if let leaf = try leaf(value) { return leaf }
        let place = hidden()
        try assign(place, value)
        return place
    }

    private mutating func assign(_ target: Variable, _ value: ScriptExpression) throws(ScriptError) {
        if let leaf = try leaf(value) {
            emitStep(2, expression(target, 5, leaf))
            return
        }
        switch value {
        case .unary("-", let inner, _):
            let source = try operand(inner)
            emitStep(2, expression(target, 5, .literal(0)))
            emitStep(2, expression(target, 4, source))
        case .binary(let operatorText, let left, let right, let position):
            guard let operatorValue = Self.arithmeticOperators[operatorText] else {
                throw ScriptCompiler.error("\(operatorText) gives true or false; use it in an if or while", position)
            }
            // Compute into a fresh local when the right side reads the target.
            if references(right, target) {
                let place = hidden()
                try assign(place, value)
                emitStep(2, expression(target, 5, place))
                return
            }
            try assign(target, left)
            let source = try operand(right)
            emitStep(2, expression(target, operatorValue, source))
        case .call(_, _, let position):
            throw ScriptCompiler.error("a call gives true or false; use it in an if or while", position)
        default:
            throw ScriptCompiler.error("true and false aren't numbers; use 1 and 0", value.position)
        }
    }

    private func references(_ value: ScriptExpression, _ target: Variable) -> Bool {
        switch value {
        case .variable(let name, let position): (try? variable(name, position)) == target
        case .unary(_, let inner, _): references(inner, target)
        case .binary(_, let left, let right, _): references(left, target) || references(right, target)
        case .call(_, let arguments, _): arguments.contains { references($0, target) }
        default: false
        }
    }

    // MARK: Conditions

    private mutating func condition(_ value: ScriptExpression, onTrue: Label, onFalse: Label) throws(ScriptError) {
        switch value {
        case .boolean(let isTrue, _):
            // A real test, not a jump: a jump can't start a routine or a loop.
            branch(2, expression(.literal(0), isTrue ? 2 : 16, .literal(0)), onTrue, onFalse)
        case .integer(let number, _):
            branch(2, expression(.literal(0), number != 0 ? 2 : 16, .literal(0)), onTrue, onFalse)
        case .unary("!", let inner, _):
            try condition(inner, onTrue: onFalse, onFalse: onTrue)
        case .binary("&&", let left, let right, _):
            let next = Label()
            try condition(left, onTrue: next, onFalse: onFalse)
            place(next)
            try condition(right, onTrue: onTrue, onFalse: onFalse)
        case .binary("||", let left, let right, _):
            let next = Label()
            try condition(left, onTrue: onTrue, onFalse: next)
            place(next)
            try condition(right, onTrue: onTrue, onFalse: onFalse)
        case .binary(let operatorText, let left, let right, _) where Self.comparisonOperators[operatorText] != nil:
            let leftOperand = try operand(left), rightOperand = try operand(right)
            branch(2, expression(leftOperand, Self.comparisonOperators[operatorText] ?? 2, rightOperand), onTrue, onFalse)
        case .call(let name, let arguments, let position):
            let (trueEdge, falseEdge) = try call(name, arguments, position)
            attach(trueEdge, to: onTrue)
            attach(falseEdge, to: onFalse)
        default:
            let number = try operand(value)
            branch(2, expression(number, 16, .literal(0)), onTrue, onFalse)
        }
    }

    private mutating func branch(_ opcode: UInt16, _ operand: [UInt8], _ onTrue: Label, _ onFalse: Label) {
        let (trueEdge, falseEdge) = emit(opcode, operand)
        attach(trueEdge, to: onTrue)
        attach(falseEdge, to: onFalse)
    }

    // MARK: Calls

    /// Emits a call. Plain-number arguments go in the operand; otherwise all four go through temps,
    /// with every argument -1, which 2017 reads as "take the temp" when arguments 1 to 3 aren't all 0.
    private mutating func call(_ name: String, _ arguments: [ScriptExpression], _ position: SourcePosition) throws(ScriptError) -> (Edge, Edge) {
        guard let routine = routines[name] else { throw ScriptCompiler.error("\(name) isn't a function", position) }
        guard arguments.count == routine.parameters else {
            throw ScriptCompiler.error("\(name) takes \(routine.parameters) arguments, not \(arguments.count)", position)
        }
        var literals: [Int16] = []
        for argument in arguments {
            guard let value = try leaf(argument), value.scope == .literal, value.data != -1 else { break }
            literals.append(value.data)
        }
        if literals.count == arguments.count {
            return emit(UInt16(routine.id), SubroutineOperand(arguments: literals).encoded())
        }
        let values = try arguments.map { (argument) throws(ScriptError) in try operand(argument) }
        for (index, value) in values.enumerated() {
            emitStep(2, expression(Variable(.temps, Int16(index)), 5, value))
        }
        return emit(UInt16(routine.id), SubroutineOperand(arguments: [-1, -1, -1, -1]).encoded())
    }

}
