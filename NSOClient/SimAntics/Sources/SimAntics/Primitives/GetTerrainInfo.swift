extension Primitives {
    /// Reads the ground around the caller or the stack object into temps (opcode 63).
    ///
    /// Ports FreeSO's `VMGetTerrainInfo`. Out of the world it's false. Mode 0 gives the heights at
    /// the four corners of its tile (TSO's units, FreeSO's divided by 10); mode 1 the slope across
    /// and down; mode 2 its tile, the position within the tile, and its level; modes 3 (grass) and
    /// 4 (a ceiling above) are 0, as in FreeSO. Terrain isn't ported, so heights and slopes are 0,
    /// as on every blueprint lot. A missing object fails, as FreeSO's null reference does.
    public enum GetTerrainInfo: Primitive {
        public static let name = "get_terrain_info"
        public static let opcode: UInt8 = 63

        public struct Operand: PrimitiveOperand, Equatable {
            public var mode: UInt8
            public var unknown1: UInt8
            /// Bit 1: the caller instead of the stack object.
            public var flags: UInt8
            public var unknown: [UInt8]

            public init(mode: UInt8, flags: UInt8 = 0) {
                self.mode = mode
                unknown1 = 0
                self.flags = flags
                unknown = [0, 0, 0, 0, 0]
            }

            public init(bytes: [UInt8]) {
                var reader = OperandReader(bytes)
                mode = reader.uint8()
                unknown1 = reader.uint8()
                flags = reader.uint8()
                unknown = (0..<5).map { _ in reader.uint8() }
            }

            public func encoded() -> [UInt8] {
                OperandWriter.bytes { writer in
                    writer.uint8(mode)
                    writer.uint8(unknown1)
                    writer.uint8(flags)
                    unknown.prefix(5).forEach { writer.uint8($0) }
                }
            }

            public var useMe: Bool { flags & 2 != 0 }
        }

        public static func execute(_ operand: Operand, in frame: StackFrame) throws(SimAnticsError) -> ExitCode {
            guard let entity = operand.useMe ? frame.caller : frame.stackObject else {
                throw .nullReference("Get Terrain Info with no \(operand.useMe ? "caller" : "stack object")")
            }
            let position = entity.position
            guard !position.isOutOfWorld else { return .gotoFalse }
            let architecture = frame.vm.architecture
            let x = Int(position.tileX), y = Int(position.tileY)
            let right = min(architecture.width - 1, x + 1), below = min(architecture.height - 1, y + 1)
            let thread = frame.thread
            switch operand.mode {
            case 0:
                thread.tempRegisters[0] = architecture.terrainHeight(atX: x, y: y) / 10
                thread.tempRegisters[1] = architecture.terrainHeight(atX: right, y: y) / 10
                thread.tempRegisters[2] = architecture.terrainHeight(atX: x, y: below) / 10
                thread.tempRegisters[3] = architecture.terrainHeight(atX: right, y: below) / 10
            case 1:
                let h1 = Int(architecture.terrainHeight(atX: x, y: y)), h2 = Int(architecture.terrainHeight(atX: right, y: y))
                let h3 = Int(architecture.terrainHeight(atX: x, y: below)), h4 = Int(architecture.terrainHeight(atX: right, y: below))
                thread.tempRegisters[0] = Int16(truncatingIfNeeded: ((h1 - h2) + (h3 - h4)) / 20)
                thread.tempRegisters[1] = Int16(truncatingIfNeeded: ((h3 - h1) + (h4 - h2)) / 20)
            case 2:
                thread.tempRegisters[0] = position.tileX
                thread.tempRegisters[1] = position.x % 16
                thread.tempRegisters[2] = position.tileY
                thread.tempRegisters[3] = position.y % 16
                thread.tempRegisters[4] = Int16(position.level)
            case 3, 4:
                thread.tempRegisters[0] = 0
            default:
                break
            }
            return .gotoTrue
        }
    }
}
