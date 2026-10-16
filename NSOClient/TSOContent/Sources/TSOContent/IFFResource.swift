import TSOFiles

/// Behavior and data that SimAntics code reads through its code owner: an object's
/// files, or a global or semi-global file.
///
/// Ports FreeSO's `GameIffResource`.
public protocol IFFResource: Sendable {
    /// The IFF that holds the code.
    var mainFile: IFFFile { get }
    /// The semi-global this resource falls back to for shared code and tuning, if any.
    var semiGlobal: GlobalResource? { get }
    /// A chunk by ID, or `nil` if there isn't one.
    func chunk<Chunk: IFFChunk>(_ type: Chunk.Type, id: UInt16) throws(IFFChunkError) -> Chunk?
    /// Every chunk of a type.
    func chunks<Chunk: IFFChunk>(_ type: Chunk.Type) throws(IFFChunkError) -> [Chunk]
    /// A tuning table from the resource's OTF, or `nil` if there isn't one.
    func tuningTable(id: UInt16) -> OTFFile.Table?
}

/// What happened when the registered patches were applied to a file.
public struct PatchReport: Sendable, Equatable {
    public var applied: [String]
    public var skipped: [PatchRegistry.SkippedPatch]

    public static let none = PatchReport(applied: [], skipped: [])
}

/// A global or semi-global: an IFF from `objectdata/globals` and its tuning.
///
/// Ports FreeSO's `GameGlobalResource`.
public struct GlobalResource: IFFResource {
    /// The file name without extension, in lower case.
    public let name: String
    public let mainFile: IFFFile
    public let tuning: OTFFile?
    public let patches: PatchReport

    public var semiGlobal: GlobalResource? { nil }

    public init(name: String, mainFile: IFFFile, tuning: OTFFile?, patches: PatchReport = .none) {
        self.name = name
        self.mainFile = mainFile
        self.tuning = tuning
        self.patches = patches
    }

    public func chunk<Chunk: IFFChunk>(_ type: Chunk.Type, id: UInt16) throws(IFFChunkError) -> Chunk? {
        try mainFile.chunk(type, id: id)
    }

    public func chunks<Chunk: IFFChunk>(_ type: Chunk.Type) throws(IFFChunkError) -> [Chunk] {
        try mainFile.chunks(type)
    }

    public func tuningTable(id: UInt16) -> OTFFile.Table? {
        tuning?.table(id: Int32(id))
    }
}

/// An object's files: its IFF, its sprite IFF, its tuning, and its semi-global.
///
/// Ports FreeSO's `GameObjectResource`. One resource is shared by every object in the same IFF.
public struct ObjectResource: IFFResource {
    /// Chunk types that live in the sprite IFF when one is loaded.
    public static let spriteChunkTypes: Set<String> = ["SPR2", "SPR#", "DGRP"]

    /// The IFF's name: the file name in `objiff.far` without extension, or a standalone file's path.
    public let name: String
    public let mainFile: IFFFile
    public let sprites: IFFFile?
    public let tuning: OTFFile?
    public let semiGlobal: GlobalResource?
    public let patches: PatchReport
    /// Why the tuning couldn't be loaded, if it exists but failed. 2017 ignores these silently.
    public let tuningFailure: String?
    /// Routines by name for Run Tree by Name: the object's BHAVs, then its semi-global's.
    /// A name is the chunk label up to its first NUL, and the first routine with a name wins.
    public let treesByName: [String: BHAV]

    /// Builds a resource, parsing every BHAV for ``treesByName``.
    ///
    /// - Throws: An error if a BHAV in the file or its semi-global doesn't parse.
    public init(name: String, mainFile: IFFFile, sprites: IFFFile? = nil, tuning: OTFFile? = nil,
                semiGlobal: GlobalResource? = nil, patches: PatchReport = .none,
                tuningFailure: String? = nil) throws(IFFChunkError) {
        self.name = name
        self.mainFile = mainFile
        self.sprites = sprites
        self.tuning = tuning
        self.semiGlobal = semiGlobal
        self.patches = patches
        self.tuningFailure = tuningFailure

        var treesByName: [String: BHAV] = [:]
        for bhav in try mainFile.chunks(BHAV.self) + (semiGlobal?.chunks(BHAV.self) ?? []) {
            let treeName = String(bhav.label.prefix { $0 != "\0" })
            if treesByName[treeName] == nil { treesByName[treeName] = bhav }
        }
        self.treesByName = treesByName
    }

    /// A chunk from the object's IFF, else from its sprite IFF.
    public func chunk<Chunk: IFFChunk>(_ type: Chunk.Type, id: UInt16) throws(IFFChunkError) -> Chunk? {
        if let chunk = try mainFile.chunk(type, id: id) { return chunk }
        return try sprites?.chunk(type, id: id)
    }

    /// Sprite chunks from the sprite IFF when one is loaded; everything else from the object's IFF.
    public func chunks<Chunk: IFFChunk>(_ type: Chunk.Type) throws(IFFChunkError) -> [Chunk] {
        if let sprites, Self.spriteChunkTypes.contains(Chunk.typeCode) { return try sprites.chunks(type) }
        return try mainFile.chunks(type)
    }

    public func tuningTable(id: UInt16) -> OTFFile.Table? {
        tuning?.table(id: Int32(id))
    }
}
