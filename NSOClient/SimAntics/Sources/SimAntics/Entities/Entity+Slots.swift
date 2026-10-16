extension Entity {
    /// The number of container slots (`TotalSlots`): the definition's slots of type 0, once initialized.
    public var totalSlots: Int { contained.count }

    /// The object in a container slot, or `nil` for an empty or unknown slot (`GetSlot`).
    public func slot(_ index: Int) -> Entity? {
        contained.indices.contains(index) ? contained[index] : nil
    }

    /// The height of the first container slot, whatever the index, or -1 past the last (`GetSlotHeight`).
    func slotHeight(_ index: Int) -> Int {
        index < totalSlots ? Int(containerSlots[0].height) : -1
    }

    /// Whether putting `object` in one of this entity's slots would contain it in itself (`WillLoopSlot`).
    func willLoopSlot(_ object: Entity) -> Bool {
        if object === self { return true }
        return container?.willLoopSlot(object) ?? false
    }

    /// Puts an object in a container slot (`PlaceInSlot`), and returns whether it's there.
    ///
    /// It's true at once if the object is already in that slot, and false if the slot holds
    /// something else, doesn't exist, or would hold its own container. With `cleanOld`, the object
    /// first leaves its place and afterwards takes its new one (room, tile, placement entry point);
    /// either way it moves to this entity's position.
    ///
    /// - Throws: any error the object's placement or dynamic multi-tile entry point throws.
    @discardableResult
    public func placeInSlot(_ object: Entity, slot index: Int, cleanOld: Bool) throws(SimAnticsError) -> Bool {
        if slot(index) === object { return true }
        if slot(index) != nil || willLoopSlot(object) { return false }
        if cleanOld { vm.leavePosition(object) }
        guard contained.indices.contains(index) else { return false }
        contained[index] = object
        object.container = self
        object.containerSlot = Int16(index)
        object.position = position
        if cleanOld { try vm.takePosition(object, runsPlacementEntryPoint: true) }
        return true
    }

    /// Empties a container slot (`ClearSlot`).
    func clearSlot(_ index: Int) {
        guard contained.indices.contains(index), let object = contained[index] else { return }
        object.container = nil
        object.containerSlot = -1
        contained[index] = nil
    }
}
