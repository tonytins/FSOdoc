extension Primitives {
    /// Creates an object (opcode 42).
    ///
    /// Ports FreeSO's `VMCreateObjectInstance`. The position mode picks where the new object goes:
    /// a tile next to or under the caller or an object, a slot, or out of the world. The object is
    /// created as ``VM/createObject(guid:at:facing:mainStackObjectID:mainParameter:)`` does, then
    /// becomes the stack object; anywhere but out of the world, an object that didn't get placed is
    /// deleted again and the primitive is false. The new object's main can get the stack object's ID
    /// and, as argument 0, temp 0 or the caller's ID.
    ///
    /// Not ported yet: placing in the world (placement), slots and hands (containment), callbacks
    /// that run an interaction on the new object, and a neighbor's Sim (The Sims 1). Each throws
    /// ``SimAnticsError/unsupported(_:)``. Persisting the object gives it a database ID in 2017,
    /// which nothing here models.
    public enum CreateObjectInstance: Primitive {
        public static let name = "create_object_instance"
        public static let opcode: UInt8 = 42

        /// Where the new object goes (`VMCreateObjectPosition`).
        public enum Position: UInt8, Sendable, CaseIterable {
            case inFrontOfMe = 0, onTopOfMe, inMyHand, inFrontOfStackObject, inSlot0OfStackObject
            case underneathMe, outOfWorld, belowObjectInStackParameter0, belowObjectInLocal
            case nextToMeInDirectionOfLocal
        }

        /// The operand flags, with 2017's bit values.
        public struct Flags: OptionSet, Sendable, Hashable {
            public var rawValue: UInt8
            public init(rawValue: UInt8) { self.rawValue = rawValue }

            /// Main gets the stack object's ID, and (without ``passTemp0``) the caller's ID as argument 0.
            public static let passObjectIDs = Flags(rawValue: 2)
            /// Create the Sim of the neighbor whose ID is the stack object ID (The Sims 1).
            public static let useNeighbor = Flags(rawValue: 4)
            public static let failIfNonEmpty = Flags(rawValue: 8)
            /// Main gets temp 0 as argument 0.
            public static let passTemp0 = Flags(rawValue: 16)
            public static let faceStackObjectDirection = Flags(rawValue: 32)
            /// Run an interaction on the new object instead of making it the stack object.
            public static let returnImmediately = Flags(rawValue: 64)
            public static let persistInDatabase = Flags(rawValue: 128)
        }

        public struct Operand: PrimitiveOperand, Equatable {
            public var guid: UInt32
            /// The raw position byte; one with no ``Position`` fails when run.
            public var rawPosition: UInt8
            public var flags: Flags
            /// The local holding an object ID or a direction, for the modes that read one.
            public var local: UInt8
            public var interactionCallback: UInt8

            public init(guid: UInt32, position: Position, flags: Flags = [], local: UInt8 = 0, interactionCallback: UInt8 = 0) {
                self.guid = guid
                rawPosition = position.rawValue
                self.flags = flags
                self.local = local
                self.interactionCallback = interactionCallback
            }

            public init(bytes: [UInt8]) {
                var reader = OperandReader(bytes)
                guid = reader.uint32()
                rawPosition = reader.uint8()
                flags = Flags(rawValue: reader.uint8())
                local = reader.uint8()
                interactionCallback = reader.uint8()
            }

            public func encoded() -> [UInt8] {
                OperandWriter.bytes { writer in
                    writer.uint32(guid)
                    writer.uint8(rawPosition)
                    writer.uint8(flags.rawValue)
                    writer.uint8(local)
                    writer.uint8(interactionCallback)
                }
            }
        }

        public static func execute(_ operand: Operand, in frame: StackFrame) throws(SimAnticsError) -> ExitCode {
            let vm = frame.vm
            guard let mode = Position(rawValue: operand.rawPosition) else { throw .simantics("Where do I put this??") }
            let (position, direction) = try target(of: mode, operand: operand, in: frame)
            if mode == .inSlot0OfStackObject || mode == .inMyHand {
                throw .unsupported("creating an object in a slot needs containment")
            }

            let flags = operand.flags
            let mainStackObjectID = flags.contains(.passObjectIDs) ? frame.stackObject?.objectID ?? 0 : 0
            let mainParameter: Int16
            if flags.contains(.passTemp0) {
                mainParameter = frame.thread.tempRegisters[0]
            } else if flags.contains(.passObjectIDs) {
                guard let caller = frame.caller else { throw .nullReference("no caller") }
                mainParameter = caller.objectID
            } else {
                mainParameter = 0
            }
            guard let group = try vm.createObject(guid: operand.guid, at: position, facing: direction,
                                                  mainStackObjectID: mainStackObjectID, mainParameter: mainParameter),
                  let object = group.leadObject else { return .gotoFalse }

            if mode == .underneathMe && object.position.isOutOfWorld {
                guard let caller = frame.caller else { throw .nullReference("no caller") }
                guard caller.position.isOutOfWorld else {
                    throw .unsupported("placing an object in the world needs placement")
                }
                vm.moveOutOfWorld(group, facing: direction)
            }
            if mode != .outOfWorld && object.position.isOutOfWorld {
                vm.delete(object, wholeGroup: true)
                return .gotoFalse
            }
            if flags.contains(.returnImmediately) {
                throw .unsupported("an interaction callback on a new object needs interactions")
            }
            frame.stackObject = object
            if flags.contains(.useNeighbor) {
                throw .invalidCast("only a Sim can inherit a neighbor") // 2017 casts the new object to a Sim
            }
            return .gotoTrue
        }

        /// Where a mode puts the new object, before placement: out of the world, or relative to the
        /// caller or another object, which fails as 2017 does when that object doesn't exist.
        private static func target(of mode: Position, operand: Operand,
                                   in frame: StackFrame) throws(SimAnticsError) -> (LotPosition, Direction) {
            func object(_ id: Int16) throws(SimAnticsError) -> Entity {
                guard let entity = frame.vm.entity(id: id) else { throw .nullReference("no object \(id)") }
                return entity
            }
            func local() throws(SimAnticsError) -> Int16 {
                guard Int(operand.local) < frame.locals.count else { throw .indexOutOfRange("local \(operand.local)") }
                return frame.locals[Int(operand.local)]
            }
            func caller() throws(SimAnticsError) -> Entity {
                guard let caller = frame.caller else { throw .nullReference("no caller") }
                return caller
            }
            switch mode {
            case .underneathMe, .onTopOfMe:
                return (try caller().position, .north)
            case .belowObjectInLocal:
                return (try object(try local()).position, .north)
            case .belowObjectInStackParameter0:
                guard let argument = frame.arguments.first else { throw .indexOutOfRange("parameter 0") }
                return (try object(argument).position, .north)
            case .outOfWorld, .inSlot0OfStackObject, .inMyHand:
                return (.outOfWorld, .north)
            case .inFrontOfStackObject, .inFrontOfMe:
                let anchor: Entity
                if mode == .inFrontOfStackObject {
                    guard let stackObject = frame.stackObject else { throw .nullReference("no stack object") }
                    anchor = stackObject
                } else {
                    anchor = try caller()
                }
                var position = anchor.position
                switch anchor.direction {
                case .south: position.y &+= 16
                case .west: position.x &-= 16
                case .east: position.x &+= 16
                case .north: position.y &-= 16
                default: break
                }
                return (position, anchor.direction)
            case .nextToMeInDirectionOfLocal:
                var position = try caller().position
                switch try local() {
                case 0: position.y &-= 16; return (position, .north)
                case 2: position.x &+= 16; return (position, .east)
                case 4: position.y &+= 16; return (position, .south)
                case 6: position.x &-= 16; return (position, .west)
                default: return (position, .north)
                }
            }
        }
    }
}
