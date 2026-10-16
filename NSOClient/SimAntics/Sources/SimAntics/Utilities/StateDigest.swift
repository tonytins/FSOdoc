/// A hash of the VM state that matches `fso-oracle`'s digest version 0, for comparing a
/// Swift VM with the 2017 one tick by tick.
///
/// SHA-256 over little-endian values: the random seed (64 bits); the entity count (32);
/// then for each entity in object ID order: object ID (16), GUID (32), tile x (16),
/// tile y (16), level (8), direction (8, 2017's compass flag), the object data count (32)
/// and values (16 each), and the stack depth (32), then each frame's routine ID (16) and
/// instruction pointer (16). Positions aren't ported yet, so every entity is out of the
/// world (x and y -32768, level 1), which is right only for objects 2017 keeps there.
public enum StateDigest {
    public static let version = 0

    /// The digest as 64 lower-case hexadecimal digits.
    public static func hex(of vm: VM) -> String {
        SHA256.hash(bytes(of: vm)).map { byte in
            let digits = Array("0123456789abcdef")
            return String([digits[Int(byte >> 4)], digits[Int(byte & 15)]])
        }.joined()
    }

    static func bytes(of vm: VM) -> [UInt8] {
        var bytes: [UInt8] = []
        func append<Value: FixedWidthInteger>(_ value: Value) {
            withUnsafeBytes(of: value.littleEndian) { bytes.append(contentsOf: $0) }
        }
        append(vm.random.seed)
        append(Int32(vm.entities.count))
        for entity in vm.entities {
            append(entity.objectID)
            append(entity.object.guid)
            append(Int16.min)
            append(Int16.min)
            append(Int8(1))
            append(UInt8(1) << UInt8(entity.directionNotch & 7))
            append(Int32(entity.objectData.count))
            for value in entity.objectData { append(value) }
            append(Int32(entity.thread.stack.count))
            for frame in entity.thread.stack {
                append(frame.routine.id)
                append(frame.instructionPointer)
            }
        }
        return bytes
    }
}
