extension Primitives {
    /// Compares, assigns, and does arithmetic on two variables (opcode 2).
    ///
    /// Ports FreeSO's `VMExpression`. Values are read as 32-bit integers (only `TempXL`
    /// holds more than 16 bits) and written back truncated. Arithmetic wraps, as C#'s
    /// unchecked `int` does, and shift counts are masked to 5 bits. Quirks kept from 2017:
    ///
    /// - Dividing by zero sets -1; a remainder by zero leaves the value unchanged.
    /// - `int.MinValue / -1` and `% -1` fail, as .NET throws on them.
    /// - Clear Flag truncates its mask to 16 bits before applying it.
    /// - Push to a position other than 0, 1, or 2 does nothing; pop from one sets 0.
    /// - The operand's signed flag is ignored.
    public enum Expression: Primitive {
        public static let name = "expression"
        public static let opcode: UInt8 = 2

        /// `VMExpressionOperator`.
        public enum Operator: UInt8, Sendable, CaseIterable {
            case greaterThan = 0, lessThan, equals, plusEquals, minusEquals, assign, multiplyEquals, divideEquals
            case isFlagSet, setFlag, clearFlag, incrementAndLessThan, moduloEquals, andEquals
            case greaterThanOrEqualTo, lessThanOrEqualTo, notEqualTo, decrementAndGreaterThan, push, pop
        }

        public struct Operand: PrimitiveOperand, Equatable {
            public var lhsData: Int16
            public var rhsData: Int16
            public var isSigned: UInt8
            /// The raw operator byte; one with no ``Operator`` fails when run.
            public var rawOperator: UInt8
            public var lhsScope: UInt8
            public var rhsScope: UInt8

            public init(bytes: [UInt8]) {
                var reader = OperandReader(bytes)
                lhsData = reader.int16()
                rhsData = reader.int16()
                isSigned = reader.uint8()
                rawOperator = reader.uint8()
                lhsScope = reader.uint8()
                rhsScope = reader.uint8()
            }
        }

        public static func execute(_ operand: Operand, in frame: StackFrame) throws(SimAnticsError) -> ExitCode {
            func lhs() throws(SimAnticsError) -> Int32 {
                try VMMemory.bigValue(scope: operand.lhsScope, data: operand.lhsData, in: frame)
            }
            func rhs() throws(SimAnticsError) -> Int32 {
                try VMMemory.bigValue(scope: operand.rhsScope, data: operand.rhsData, in: frame)
            }
            @discardableResult
            func setLHS(_ value: Int32) throws(SimAnticsError) -> Bool {
                try VMMemory.setBigValue(value, scope: operand.lhsScope, data: operand.lhsData, in: frame)
            }
            func branch(_ condition: Bool) -> ExitCode { condition ? .gotoTrue : .gotoFalse }

            guard let `operator` = Operator(rawValue: operand.rawOperator) else {
                throw .simantics("Unknown expression type")
            }
            switch `operator` {
            case .assign:
                return branch(try setLHS(try rhs()))
            case .incrementAndLessThan:
                let value = try lhs() &+ 1
                try setLHS(value)
                return branch(value < (try rhs()))
            case .decrementAndGreaterThan:
                let value = try lhs() &- 1
                try setLHS(value)
                return branch(value > (try rhs()))
            case .setFlag:
                let value = try lhs()
                return branch(try setLHS(value | bit(try rhs())))
            case .clearFlag:
                let value = try lhs()
                let mask = Int32(Int16(truncatingIfNeeded: ~bit(try rhs())))
                return branch(try setLHS(value & mask))
            case .plusEquals, .minusEquals, .multiplyEquals, .divideEquals, .moduloEquals, .andEquals:
                let value = try lhs()
                try setLHS(try arithmetic(`operator`, value, try rhs()))
                return .gotoTrue
            case .equals:
                return branch(try lhs() == (try rhs()))
            case .lessThan:
                return branch(try lhs() < (try rhs()))
            case .greaterThan:
                return branch(try lhs() > (try rhs()))
            case .greaterThanOrEqualTo:
                let left = try lhs(), right = try rhs()
                if right == 1024, operand.lhsData == ObjectVariable.room.rawValue,
                   operand.lhsScope == VariableScope.myObject.rawValue {
                    throw .unsupported("the upstairs room test needs positions")
                }
                return branch(left >= right)
            case .notEqualTo:
                return branch(try lhs() != (try rhs()))
            case .lessThanOrEqualTo:
                return branch(try lhs() <= (try rhs()))
            case .isFlagSet:
                let value = try lhs()
                return branch(value & bit(try rhs()) > 0)
            case .push:
                let owner = try VMMemory.listOwner(scope: operand.lhsScope, in: frame)
                let value = Int16(truncatingIfNeeded: try rhs())
                switch operand.lhsData {
                case 0: owner.list.insert(value, at: 0)
                case 1: owner.list.append(value)
                case 2: throw .simantics("Unknown list push destination: 2")
                default: break
                }
                return .gotoTrue
            case .pop:
                let owner = try VMMemory.listOwner(scope: operand.rhsScope, in: frame)
                guard !owner.list.isEmpty else { return .gotoFalse }
                var value: Int32 = 0
                switch operand.rhsData {
                case 0: value = Int32(owner.list.removeFirst())
                case 1: value = Int32(owner.list.removeLast())
                case 2: throw .simantics("Unknown list pop source: \(operand.lhsData)")
                default: break
                }
                try setLHS(value)
                return .gotoTrue
            }
        }

        /// `1 << (n - 1)` with C#'s shift: the count is masked to 5 bits.
        private static func bit(_ position: Int32) -> Int32 {
            1 << ((position &- 1) & 31)
        }

        private static func arithmetic(_ operator: Operator, _ left: Int32, _ right: Int32) throws(SimAnticsError) -> Int32 {
            switch `operator` {
            case .plusEquals:
                return left &+ right
            case .minusEquals:
                return left &- right
            case .multiplyEquals:
                return left &* right
            case .andEquals:
                return left & right
            case .divideEquals:
                if right == 0 { return -1 }
                let (quotient, overflow) = left.dividedReportingOverflow(by: right)
                if overflow { throw .overflow("\(left) / \(right)") }
                return quotient
            default: // .moduloEquals: ((left % right + right) % right)
                if right == 0 { return left }
                let (remainder, overflow) = left.remainderReportingOverflow(dividingBy: right)
                if overflow { throw .overflow("\(left) % \(right)") }
                return (remainder &+ right).remainderReportingOverflow(dividingBy: right).partialValue
            }
        }
    }
}
