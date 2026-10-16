extension Primitives {
    /// Plays a sound event on the caller or the stack object (opcode 23).
    ///
    /// Corresponds to FreeSO's `VMPlaySound`. The simulation doesn't play sound: FreeSO returns
    /// true at once whenever the VM has no world to present, as on the lot server, and that's
    /// the behavior here. Playing the event (its `FWAV` from the code owner's file or the
    /// global) belongs to a presentation layer built on top of the VM.
    ///
    /// Unlike FreeSO clients, an object playing a sound isn't made to run every tick: that is a
    /// client-only scheduling change the server never makes, so the headless behavior is the
    /// one lockstep play agrees on.
    public enum PlaySound: Primitive {
        public static let name = "play_sound"
        public static let opcode: UInt8 = 23

        /// How the sound plays.
        public struct Options: OptionSet, Sendable, Hashable {
            public let rawValue: UInt8

            public init(rawValue: UInt8) {
                self.rawValue = rawValue
            }

            public static let loops = Options(rawValue: 1 << 0)
            /// The stack object makes the sound, not the caller.
            public static let fromStackObject = Options(rawValue: 1 << 1)
            /// The volume doesn't follow the camera's zoom.
            public static let ignoresZoom = Options(rawValue: 1 << 2)
            /// The sound isn't panned by its position on screen.
            public static let ignoresPan = Options(rawValue: 1 << 3)
        }

        public struct Operand: PrimitiveOperand, Equatable {
            /// The `FWAV` chunk naming the sound event.
            public var event: UInt16
            /// Two bytes FreeSO reads and keeps but never uses.
            public var padding: UInt16
            public var options: Options
            public var volume: UInt8

            public init(event: UInt16, options: Options = [], volume: UInt8 = 0, padding: UInt16 = 0) {
                self.event = event
                self.padding = padding
                self.options = options
                self.volume = volume
            }

            public init(bytes: [UInt8]) {
                var reader = OperandReader(bytes)
                event = reader.uint16()
                padding = reader.uint16()
                options = Options(rawValue: reader.uint8())
                volume = reader.uint8()
            }

            public func encoded() -> [UInt8] {
                OperandWriter.bytes { writer in
                    writer.uint16(event)
                    writer.uint16(padding)
                    writer.uint8(options.rawValue)
                    writer.uint8(volume)
                }
            }
        }

        public static func execute(_ operand: Operand, in frame: StackFrame) throws(SimAnticsError) -> ExitCode {
            .gotoTrue
        }
    }
}
