import TSOFiles

extension Primitives {
    /// Runs one of the stack object's routines, found by a name from a string table (opcode 28).
    ///
    /// Ports FreeSO's `VMRunTreeByName`. The name is a string from a table in the global (scope 1)
    /// or else the code owner's semi-global (in a semi-global routine) or file. The routine with that
    /// name in the stack object's file or semi-global then runs with the stack object as its code
    /// owner and the caller's first four temps as its arguments: pushed as a subroutine (destination
    /// 2), or run to completion on the caller's thread (0) or the stack object's (anything else),
    /// which is true if it returned true. No stack object, table, or routine of that name is false;
    /// a string index out of range fails, as FreeSO's lookup throws.
    public enum RunTreeByName: Primitive {
        public static let name = "run_tree_by_name"
        public static let opcode: UInt8 = 28

        public struct Operand: PrimitiveOperand, Equatable {
            public var stringTable: UInt16
            /// 1 for the global's tables; anything else for the code owner's.
            public var stringScope: UInt8
            public var unused: UInt8
            /// The string's index, from 1.
            public var stringID: UInt8
            /// 2 pushes the routine; 0 runs it on the caller's thread; anything else on the stack object's.
            public var destination: UInt8

            public init(stringTable: UInt16, stringScope: UInt8, unused: UInt8 = 0, stringID: UInt8, destination: UInt8) {
                self.stringTable = stringTable
                self.stringScope = stringScope
                self.unused = unused
                self.stringID = stringID
                self.destination = destination
            }

            public init(bytes: [UInt8]) {
                var reader = OperandReader(bytes)
                stringTable = reader.uint16()
                stringScope = reader.uint8()
                unused = reader.uint8()
                stringID = reader.uint8()
                destination = reader.uint8()
            }

            public func encoded() -> [UInt8] {
                OperandWriter.bytes { writer in
                    writer.uint16(stringTable)
                    writer.uint8(stringScope)
                    writer.uint8(unused)
                    writer.uint8(stringID)
                    writer.uint8(destination)
                }
            }
        }

        public static func execute(_ operand: Operand, in frame: StackFrame) throws(SimAnticsError) -> ExitCode {
            guard let stackObject = frame.stackObject else { return .gotoFalse }
            guard let table = try stringTable(operand, in: frame) else { return .gotoFalse }
            // FreeSO's GetString(StringID - 1): an index of -1 throws, and one past the end gives null,
            // which the name lookup then throws on.
            let index = Int(operand.stringID) - 1
            guard index >= 0 else { throw .indexOutOfRange("string \(index) of STR# \(operand.stringTable)") }
            guard let name = table.table.string(at: index) else {
                throw .nullReference("string \(index) of STR# \(operand.stringTable)")
            }
            guard let routine = frame.vm.routine(named: name, in: stackObject.object) else { return .gotoFalse }

            let thread = frame.thread
            switch operand.destination {
            case 2:
                // ExecuteSubRoutine: pushed onto the caller's stack, like a subroutine call.
                let child = StackFrame(thread: thread, routine: routine, caller: frame.caller, callee: frame.callee,
                                       codeOwner: stackObject.object)
                child.stackObject = frame.stackObject
                child.isActionTree = frame.isActionTree
                child.arguments = (0..<max(Int(routine.argumentCount), 4)).map { $0 > 3 ? -1 : thread.tempRegisters[$0] }
                thread.push(child)
                return .continue
            case 0:
                return try thread.runInMyStack(routine, codeOwner: stackObject.object, arguments: thread.tempRegisters,
                                               stackObject: stackObject) ? .gotoTrue : .gotoFalse
            default:
                return try stackObject.thread.runInMyStack(routine, codeOwner: stackObject.object,
                                                           arguments: thread.tempRegisters, stackObject: stackObject)
                    ? .gotoTrue : .gotoFalse
            }
        }

        /// The table the name comes from: the global's for scope 1; otherwise the code owner's
        /// semi-global's (only in a semi-global routine, 8192 and up), then the code owner's.
        private static func stringTable(_ operand: Operand, in frame: StackFrame) throws(SimAnticsError) -> STR? {
            do {
                if operand.stringScope == 1 { return try frame.vm.global.chunk(STR.self, id: operand.stringTable) }
                if frame.routine.id >= 8192, let semiGlobal = frame.codeOwner.resource.semiGlobal,
                   let table = try semiGlobal.chunk(STR.self, id: operand.stringTable) {
                    return table
                }
                return try frame.codeOwner.resource.chunk(STR.self, id: operand.stringTable)
            } catch {
                throw .simantics("STR# \(operand.stringTable) doesn't parse: \(error)")
            }
        }
    }
}
