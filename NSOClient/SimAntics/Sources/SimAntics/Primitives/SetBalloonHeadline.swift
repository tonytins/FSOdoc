extension Primitives {
    /// Shows or clears a balloon over the caller or the stack object (opcode 41).
    ///
    /// Ports FreeSO's `VMSetBalloonHeadline`. An index of -1 or a duration of 0 clears it; otherwise
    /// it shows for the duration (in loops of 15 ticks with that flag), or until replaced if negative.
    /// An algorithmic headline (group 7) shows an object's picture: the stack object for index 0 or
    /// 1, else the object whose ID is in the local the operand names. An indexed one adds temp 0 to
    /// the index. Headless, nothing is drawn, but the headline counts down each tick and keeps its
    /// entity running every tick. A missing target fails, as FreeSO's null reference does, and so
    /// does a local past the frame's.
    public enum SetBalloonHeadline: Primitive {
        public static let name = "set_balloon_headline"
        public static let opcode: UInt8 = 41

        public struct Operand: PrimitiveOperand, Equatable {
            /// Bit 0: the stack object instead of the caller; the rest, the local for an algorithmic icon.
            public var flags2: UInt16
            public var index: Int8
            public var group: UInt8
            public var duration: Int16
            public var type: UInt8
            /// Bit 0 inactive, 1 crossed, 2 backwards, 3 duration in loops, 4 indexed.
            public var flags: UInt8

            public init(flags2: UInt16 = 0, index: Int8, group: UInt8, duration: Int16, type: UInt8 = 0, flags: UInt8 = 0) {
                self.flags2 = flags2
                self.index = index
                self.group = group
                self.duration = duration
                self.type = type
                self.flags = flags
            }

            public init(bytes: [UInt8]) {
                var reader = OperandReader(bytes)
                flags2 = reader.uint16()
                index = Int8(bitPattern: reader.uint8())
                group = reader.uint8()
                duration = reader.int16()
                type = reader.uint8()
                flags = reader.uint8()
            }

            public func encoded() -> [UInt8] {
                OperandWriter.bytes { writer in
                    writer.uint16(flags2)
                    writer.uint8(UInt8(bitPattern: index))
                    writer.uint8(group)
                    writer.int16(duration)
                    writer.uint8(type)
                    writer.uint8(flags)
                }
            }

            public var ofStackObject: Bool { flags2 & 1 != 0 }
            /// The local holding the icon object's ID, for an algorithmic headline.
            public var algorithmicLocal: Int { Int(flags2 >> 1) }
            public var durationInLoops: Bool { flags & 0x08 != 0 }
            public var indexed: Bool { flags & 0x10 != 0 }
        }

        static let algorithmicGroup: UInt8 = 7

        public static func execute(_ operand: Operand, in frame: StackFrame) throws(SimAnticsError) -> ExitCode {
            guard let target = operand.ofStackObject ? frame.stackObject : frame.caller else {
                throw .nullReference("Set Balloon Headline with no \(operand.ofStackObject ? "stack object" : "caller")")
            }
            if operand.index == -1 || operand.duration == 0 {
                target.headline = nil
                return .gotoTrue
            }
            var index = Int(operand.index)
            var icon: Int16?
            if operand.group == algorithmicGroup {
                if index < 2 {
                    icon = frame.stackObject?.objectID
                } else {
                    guard operand.algorithmicLocal < frame.locals.count else {
                        throw .indexOutOfRange("local \(operand.algorithmicLocal)")
                    }
                    icon = frame.vm.entity(id: frame.locals[operand.algorithmicLocal])?.objectID
                }
            } else if operand.indexed {
                index += Int(frame.thread.tempRegisters[0])
            }
            let duration = operand.durationInLoops && operand.duration != -1 ? Int(operand.duration) * 15 : Int(operand.duration)
            target.headline = Headline(group: operand.group, index: Int8(truncatingIfNeeded: index), duration: duration,
                                       type: operand.type, flags: operand.flags, iconObjectID: icon)
            return .gotoTrue
        }
    }
}
