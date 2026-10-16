import TSOContent

/// An object on the lot.
///
/// Ports the parts of FreeSO's `VMEntity` and `VMGameObject` that SimAntics variables
/// read and write. Sims (`VMAvatar`), containers and slots, multi-tile groups, positions,
/// and interactions aren't ported yet; reading values that need them throws
/// ``SimAnticsError/unsupported(_:)``.
///
/// Known gaps in writes, which store the value but skip a 2017 side effect: `flags`
/// doesn't recompute the footprint (no routing yet), and `category` doesn't update
/// the object query index (no queries yet).
public final class Entity {
    public let objectID: Int16
    public let object: GameObject
    public unowned let vm: VM
    /// The 80 object data values (see ``ObjectVariable``).
    public var objectData = [Int16](repeating: 0, count: ObjectVariable.count)
    /// Attributes, grown with zeros whenever an index past the end is read or written, as in 2017.
    public private(set) var attributes: [Int16] = []
    /// The entity's list (`MyList`), front first.
    public var list: [Int16] = []
    /// The facing, as an index into the eight compass directions from north, clockwise.
    public var directionNotch: Int16 = 0

    /// Which dynamic sprites show: bits 0 to 63, then 64 to 127.
    public var dynamicSpriteFlags: (UInt64, UInt64) = (0, 0)

    private var lockoutTimestamp: UInt32 = 0

    /// The entity's interpreter.
    public private(set) lazy var thread = VMThread(entity: self)

    init(objectID: Int16, object: GameObject, vm: VM) {
        self.objectID = objectID
        self.object = object
        self.vm = vm
    }

    // MARK: Attributes

    public func attribute(at index: UInt16) -> Int16 {
        growAttributes(toInclude: index)
        return attributes[Int(index)]
    }

    public func setAttribute(_ value: Int16, at index: UInt16) {
        growAttributes(toInclude: index)
        attributes[Int(index)] = value
    }

    private func growAttributes(toInclude index: UInt16) {
        if Int(index) >= attributes.count {
            attributes.append(contentsOf: repeatElement(0, count: Int(index) + 1 - attributes.count))
        }
    }

    // MARK: Dynamic sprites

    /// Shifts are C#'s for `ulong`: the count is masked to 6 bits.
    public func isDynamicSpriteFlagSet(_ index: UInt16) -> Bool {
        index > 63 ? dynamicSpriteFlags.1 & Self.bit(Int(index) - 64) != 0 : dynamicSpriteFlags.0 & Self.bit(Int(index)) != 0
    }

    public func setDynamicSpriteFlag(_ index: UInt16, to isSet: Bool) {
        if index > 63 {
            dynamicSpriteFlags.1 = isSet ? dynamicSpriteFlags.1 | Self.bit(Int(index) - 64) : dynamicSpriteFlags.1 & ~Self.bit(Int(index) - 64)
        } else {
            dynamicSpriteFlags.0 = isSet ? dynamicSpriteFlags.0 | Self.bit(Int(index)) : dynamicSpriteFlags.0 & ~Self.bit(Int(index))
        }
    }

    private static func bit(_ shift: Int) -> UInt64 {
        1 << UInt64(shift & 63)
    }

    // MARK: Object data

    /// An object data value, as `VMEntity.GetValue` reads it.
    public func value(of variable: Int16) throws(SimAnticsError) -> Int16 {
        switch ObjectVariable(rawValue: variable) {
        case .objectID:
            return objectID
        case .direction:
            return directionNotch
        case .containerID, .parentID, .slotNumber, .slotCount:
            throw .unsupported("object data \(variable) needs containers and slots")
        case .useCount:
            throw .unsupported("object data \(variable) needs interactions")
        case .lockoutCount:
            let currentTick = vm.scheduler.currentTick
            if lockoutTimestamp > currentTick { lockoutTimestamp = 0 } // lockouts in the future are invalid
            let remaining = Int64(objectData[Int(variable)]) - Int64(currentTick - lockoutTimestamp)
            return Int16(truncatingIfNeeded: max(remaining, 0))
        default:
            return objectData[try Self.storageIndex(variable)]
        }
    }

    /// Sets an object data value, as `VMEntity.SetValue` does. Always returns `true`, as in 2017.
    @discardableResult
    public func setValue(_ value: Int16, of variable: Int16) throws(SimAnticsError) -> Bool {
        var value = value
        switch ObjectVariable(rawValue: variable) {
        case .direction:
            value = Int16((Int(value) + 65536) % 8)
            directionNotch = value
        case .lockoutCount:
            lockoutTimestamp = vm.scheduler.currentTick
        case .fsoEngineQuery where value == 1:
            throw .unsupported("the safe-to-delete query needs interactions")
        default:
            break
        }
        objectData[try Self.storageIndex(variable)] = value
        return true
    }

    private static func storageIndex(_ variable: Int16) throws(SimAnticsError) -> Int {
        if variable > 79 { throw .simantics("Object Data out of range!") }
        if variable < 0 { throw .indexOutOfRange("object data \(variable)") }
        return Int(variable)
    }
}
