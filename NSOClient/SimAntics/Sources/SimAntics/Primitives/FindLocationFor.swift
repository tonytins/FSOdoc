extension Primitives {
    /// Finds a place for the stack object (opcode 16).
    ///
    /// Ports FreeSO's `VMFindLocationFor`. The reference is the caller, or the object whose ID is in
    /// a local. Each mode tries placements (``VM/place(_:at:facing:flags:)``, accepting slots) until
    /// one fits:
    ///
    /// - 0: at the reference's tile in each compass facing, then on rings of tiles around it, out
    ///   to nine tiles;
    /// - 1: out of the world (always true);
    /// - 2: halfway between the callee and the caller, a "smoke cloud" spot half a tile up and left,
    ///   with the default flags;
    /// - 3 and 4: along the reference's facing, or across it, alternately ahead and behind, up to
    ///   15 tiles out, facing that way;
    /// - 5: random, which FreeSO leaves as true without moving anything.
    ///
    /// Other modes are false.
    public enum FindLocationFor: Primitive {
        public static let name = "find_location_for"
        public static let opcode: UInt8 = 16

        public struct Flags: OptionSet, Sendable, Hashable {
            public var rawValue: UInt8
            public init(rawValue: UInt8) { self.rawValue = rawValue }

            /// The reference is the object whose ID is in ``Operand/local``, not the caller.
            public static let useLocalAsReference = Flags(rawValue: 1)
            public static let allowIntersection = Flags(rawValue: 2)
            public static let userEditableTilesOnly = Flags(rawValue: 4)
        }

        public struct Operand: PrimitiveOperand, Equatable {
            public var mode: UInt8
            public var local: UInt8
            public var flags: Flags

            public init(mode: UInt8, local: UInt8 = 0, flags: Flags = []) {
                self.mode = mode
                self.local = local
                self.flags = flags
            }

            public init(bytes: [UInt8]) {
                var reader = OperandReader(bytes)
                mode = reader.uint8()
                local = reader.uint8()
                flags = Flags(rawValue: reader.uint8())
            }

            public func encoded() -> [UInt8] {
                OperandWriter.bytes { writer in
                    writer.uint8(mode)
                    writer.uint8(local)
                    writer.uint8(flags.rawValue)
                }
            }
        }

        /// One tile in each direction, by notch (`DirectionVectors`).
        private static let steps: [(x: Int, y: Int)] = [(0, 16), (-16, 16), (-16, 0), (-16, -16), (0, -16), (16, -16), (16, 0), (16, 16)]

        public static func execute(_ operand: Operand, in frame: StackFrame) throws(SimAnticsError) -> ExitCode {
            let vm = frame.vm
            let reference: Entity?
            if operand.flags.contains(.useLocalAsReference) {
                guard Int(operand.local) < frame.locals.count else { throw .indexOutOfRange("local \(operand.local)") }
                reference = vm.entity(id: frame.locals[Int(operand.local)])
            } else {
                reference = frame.caller
            }
            var flags: PlaceRequestFlags = .acceptSlots
            if operand.flags.contains(.userEditableTilesOnly) { flags.insert(.userBuildableLimit) }
            if operand.flags.contains(.allowIntersection) { flags.insert(.allowIntersection) }

            func object() throws(SimAnticsError) -> Entity {
                guard let object = frame.stackObject else { throw .nullReference("no stack object") }
                return object
            }
            func referenceObject() throws(SimAnticsError) -> Entity {
                guard let reference else { throw .nullReference("no reference object") }
                return reference
            }

            switch operand.mode {
            case 0:
                let target = try object()
                return try vm.findLocation(for: target, near: try referenceObject(), flags: flags) ? .gotoTrue : .gotoFalse
            case 1:
                let target = try object()
                try vm.place(target.group, at: .outOfWorld, facing: .north, flags: flags)
                return .gotoTrue
            case 2:
                guard let callee = frame.callee, let caller = frame.caller else { throw .nullReference("no caller or callee") }
                // LotTilePos arithmetic: 16-bit sums, halved toward zero, then half a tile back.
                let x = Int(Int16(truncatingIfNeeded: Int(callee.position.x) + Int(caller.position.x))) / 2 - 8
                let y = Int(Int16(truncatingIfNeeded: Int(callee.position.y) + Int(caller.position.y))) / 2 - 8
                let level = Int(Int8(truncatingIfNeeded: Int(callee.position.level) + Int(caller.position.level))) / 2
                let spot = LotPosition(x: Int16(truncatingIfNeeded: x), y: Int16(truncatingIfNeeded: y),
                                       level: Int8(truncatingIfNeeded: level))
                let target = try object()
                return try vm.place(target.group, at: spot, facing: .north).status == .success ? .gotoTrue : .gotoFalse
            case 3, 4:
                let reference = try referenceObject()
                var notch = reference.direction.notch
                if operand.mode == 4 { notch = (notch + 2) % 8 }
                return try alongVector(try object(), from: reference, notch: notch, flags: flags, in: vm) ? .gotoTrue : .gotoFalse
            case 5:
                return .gotoTrue
            default:
                return .gotoFalse
            }
        }

        /// `FindLocationVector`: tries the reference's position, then alternately a tile further
        /// ahead and behind, 32 tries in all.
        private static func alongVector(_ object: Entity, from reference: Entity, notch: Int, flags: PlaceRequestFlags,
                                        in vm: VM) throws(SimAnticsError) -> Bool {
            let step = steps[notch]
            let facing = Direction(notch: notch)
            func offset(_ count: Int) -> LotPosition {
                LotPosition(x: Int16(truncatingIfNeeded: Int(reference.position.x) + Int(Int16(truncatingIfNeeded: step.x * count))),
                            y: Int16(truncatingIfNeeded: Int(reference.position.y) + Int(Int16(truncatingIfNeeded: step.y * count))),
                            level: reference.position.level)
            }
            for attempt in 0..<32 {
                if try vm.place(object.group, at: offset(attempt / 2), facing: facing, flags: flags).status == .success { return true }
                if attempt % 2 != 0,
                   try vm.place(object.group, at: offset(-(attempt / 2)), facing: facing, flags: flags).status == .success {
                    return true
                }
            }
            return false
        }
    }
}
