extension Primitives {
    /// Draws a random number below a range (opcode 8).
    ///
    /// Corresponds to FreeSO's `VMRandomNumber`. The range is read as unsigned 16-bit, so -1
    /// means 65,535; a range of 0 gives 0 without advancing the generator. The result is written
    /// as a 16-bit value, so a `TempXL` destination fails, as in FreeSO. Always true.
    public enum RandomNumber: Primitive {
        public static let name = "random_number"
        public static let opcode: UInt8 = 8

        /// Random Number stores each scope in 16 bits.
        public struct Operand: PrimitiveOperand, Equatable {
            public var destination: Variable
            public var range: Variable

            public init(destination: Variable, range: Variable) {
                self.destination = destination
                self.range = range
            }

            public init(bytes: [UInt8]) {
                var reader = OperandReader(bytes)
                let destinationData = reader.int16()
                destination = Variable(rawScope: reader.uint16(), data: destinationData)
                let rangeData = reader.int16()
                range = Variable(rawScope: reader.uint16(), data: rangeData)
            }

            public func encoded() -> [UInt8] {
                OperandWriter.bytes { writer in
                    writer.int16(destination.data)
                    writer.uint16(destination.rawScope)
                    writer.int16(range.data)
                    writer.uint16(range.rawScope)
                }
            }
        }

        public static func execute(_ operand: Operand, in frame: StackFrame) throws(SimAnticsError) -> ExitCode {
            let range = UInt16(bitPattern: try frame.value(of: operand.range))
            let number = frame.vm.random.next(below: UInt64(range))
            try frame.setValue(Int16(truncatingIfNeeded: number), of: operand.destination)
            return .gotoTrue
        }
    }
}
