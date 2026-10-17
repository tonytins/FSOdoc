# FSO.Files: file formats

FSO.Files (`TSOClient/tso.files`) reads the original game's binary and text
formats. It is the lowest layer of the client: it depends only on
FSO.Common, MonoGame (for `Texture2D` and `Color`), and TargaImagePCL, and
nearly every other project depends on it.

## How it works (update-46)

### Binary reading

[`IoBuffer`](../../TSOClient/tso.files/utils/IoBuffer.cs) wraps `BinaryReader`
with a switchable `ByteOrder` (big or little endian), fixed-length C
strings, Pascal strings, and variable-length integers. Almost every format
reader is built on it. [`IoWriter`](../../TSOClient/tso.files/utils/IoWriter.cs)
is the writing counterpart, used where FreeSO saves files (IFF and PIFF).
[`Endian`](../../TSOClient/tso.files/Endian.cs) has byte-swap helpers.

### Archives

| Format | Type | Notes |
| --- | --- | --- |
| FAR1 | [`FAR1Archive`](../../TSOClient/tso.files/FAR1/FAR1Archive.cs) | Magic `FAR!byAZ`, version 1. A manifest lists name, size, and offset. Used by the floor, wall, and semi-global content providers and `FAR1Provider`. |
| FAR3 | [`FAR3Archive`](../../TSOClient/tso.files/FAR3/FAR3Archive.cs) | Magic `FAR!byAZ`, version 3. Entries are keyed by file name and by a 32-bit file ID. Compressed entries use RefPack (`0xFB10`), decoded by [`Decompresser`](../../TSOClient/tso.files/FAR3/Decompresser.cs), a port of DBPF4J. |
| DBPF | [`DBPFFile`](../../TSOClient/tso.files/formats/dbpf/DBPFFile.cs) | The later Maxis package format. In this snapshot only the audio content loader ([`tso.content/Audio.cs`](../../TSOClient/tso.content/Audio.cs)) uses it, with group and type IDs from `tsosounddata.ini` and `tsoaudio.ini`. |

FAR3 entries carry a type ID and a file ID that together form the 64-bit
asset IDs used throughout the content system (see [content.md](./content.md)).

`FAR3Archive` keeps its file stream open for the archive's lifetime and
serializes reads with `lock (m_Reader)`. It also has a static
`isReadingSomething` flag. The constructor only parses the manifest when
that flag is `false`, so an archive opened while another thread is inside
`GetEntry` comes back with an empty manifest and no error.

### IFF: the object container

[`IffFile`](../../TSOClient/tso.files/formats/iff/IffFile.cs) reads the
Maxis IFF container (the header must be one of the two
`IFF FILE 2.x:TYPE FOLLOWED BY SIZE JAMIE DOORNBOS & MAXIS 1` strings).
Each chunk has a 4-character type, a size, a 16-bit ID, flags, and a
64-byte label. `IffFile` keeps a static map from type code to C# class and
creates chunks with `Activator.CreateInstance`. Unknown chunk types are
skipped.

Chunks are parsed lazily: `Read` stores the raw bytes, and the chunk's own
`Read(IffFile, Stream)` runs the first time `Get<T>(id)` or `List<T>()`
asks for it. Each chunk class derives from
[`IffChunk`](../../TSOClient/tso.files/formats/iff/AbstractIffChunk.cs).

| Chunk | Class | Purpose |
| --- | --- | --- |
| `OBJD` | `OBJD` | Object definition: GUID, catalog data, entry-point BHAV IDs. The first chunk the VM reads. |
| `BHAV` | `BHAV` | SimAntics behavior code: a list of `BHAVInstruction`s. See [simantics.md](./simantics.md). |
| `BCON`, `TRCN` | `BCON`, `TRCN` | Behavior constants and their labels. |
| `TPRP` | `TPRP` | Labels for BHAV parameters and locals. |
| `TTAB`, `TTAs` | `TTAB`, `TTAs` | Interactions (pie menu entries) and their strings. |
| `OBJf` | `OBJf` | Maps object events to BHAV functions. |
| `SLOT` | `SLOT` | Positions where Sims and objects attach. |
| `GLOB` | `GLOB` | Name of the semi-global IFF an object uses. |
| `STR#`, `CTSS` | `STR`, `CTSS` | Localized string tables (`STRLangCode`). |
| `SPR#`, `SPR2`, `PALT` | `SPR`, `SPR2`, `PALT` | Paletted sprites (SPR2 adds z-buffer and alpha) and palettes. |
| `DGRP` | `DGRP` | Drawing groups: which sprites draw an object tile per direction and zoom. |
| `BMP_`, `THMB` | `BMP`, `THMB` | Embedded bitmaps and thumbnails. |
| `FWAV` | `FWAV` | Sound event names. |
| `objt`, `ObjM`, `Arry`, `WALm`, `FLRm`, `CARR` | `OBJT`, `OBJM`, `ARRY`, `WALm`, `FLRm`, `CARR` | Lot and house data (object tables, arrays, wall and floor maps) and job career data. |
| `FAMI`, `FAMs`, `NBRS`, `NGBH`, `SIMI`, `TATT` | various | The Sims 1 neighborhood and family data, used by TS1 hybrid mode. |
| `PIFF` | `PIFF` | A patch over another IFF (see below). |

`IffFile` also tracks edits for the IDE: `AddChunk`, `RemoveChunk`,
`MoveAndSwap`, `Revert`, and `Write`. When `RETAIN_CHUNK_DATA` is set,
the original bytes are kept so the IDE can diff them into a PIFF.

### Patching with PIFF and OTF

PIFF is FreeSO's own format, not TSO's: an ad hoc way to fix objects that
didn't work properly in FreeSO's engine without shipping modified game
files. FreeSO ships its patches in `Content/Patch/` (the snapshot has them in
[`tso.content/Content/Patch`](../../TSOClient/tso.content/Content/Patch/),
with copies for the mobile projects). They were written against TSO's 2003
production files, so they may not fit other versions of the game.

A PIFF is an IFF that holds a `PIFF` chunk naming a source IFF and a list
of byte-level patches. [`PIFFRegistry.Init`](../../TSOClient/tso.files/formats/iff/PIFFRegistry.cs)
scans a directory for `*.piff` and `*.otf` files. When an IFF loads from a
path, `IffFile.SetFilename` looks up the registered PIFFs for that file
name and applies each through `IffFile.Patch`. PIFFs under a
`User/` folder replace the shipped ones for the same source file. `*.otf`
files found the same way replace the matching OTF by name when the
object and semi-global providers load tuning.
[`PiffEncoder`](../../TSOClient/tso.files/formats/PiffEncoder.cs) builds a
PIFF from the differences between an edited IFF and its original.

### Other formats

| Format | Type | Purpose |
| --- | --- | --- |
| OTF | [`OTFFile`](../../TSOClient/tso.files/formats/OTF/OTFFile.cs) | Object tuning tables (an XML-like format). `VMMemory.GetTuningVariable` checks a BCON with the table's ID first and falls back to the OTF table. |
| `tuning.dat` | [`Tuning`](../../TSOClient/tso.files/Tuning.cs) | Global tuning constants, loaded by `Content`. |
| `datadefinition.dat` | [`TSODataDefinition`](../../TSOClient/tso.files/formats/tsodata/TSODataDefinition.cs) | Struct and field definitions behind the data service. Used by `FSO.Common.DataService` and the packet analyzer. See [protocol.md](./protocol.md). |
| HIT family | [`HIT/`](../../TSOClient/tso.files/HIT/) | `HITFile` (bytecode), `Hot` and `EVT` (event tables), `Hitlist`, `Track`, `HSM`, `FSC` (music sequences), `TLO`, `Patch`. See [audio.md](./audio.md). |
| UTK | [`UTKFile2`](../../TSOClient/tso.files/UTK/UTKFile2.cs) | Compressed voice audio, decoded to WAV. |
| XA | [`XAFile`](../../TSOClient/tso.files/XA/XAFile.cs) | Compressed sound effects, decoded to WAV. |
| BMP, TGA, PNG | [`ImageLoader`](../../TSOClient/tso.files/ImageLoader.cs) | Loads images into `Texture2D`. Bitmaps get magenta color-key masking. TGA goes through TargaImagePCL. |
| INI | [`IniFile`](../../TSOClient/tso.files/IniFile.cs) | Simple section and key reader. |
| CUR/ANI | [`utils/CurLoader.cs`](../../TSOClient/tso.files/utils/CurLoader.cs) | Cursor loading. |

### Dead and case-split files

The folder has both `Formats/IFF/Chunks` and `formats/iff/chunks`. On
Windows they are one folder, but on Linux and macOS they are two. The
project file uses the lower-case path for most chunks and the upper-case
path for `FAMI`, `FAMs`, `NBRS`, `NGBH`, and `TTAT`.
`formats/iff/chunks/ISPR.cs` exists but isn't compiled.

## Modern .NET rewrite

### Target

A pure library with no graphics dependency: `net10.0`, nullable enabled,
no MonoGame reference. This is the easiest project to port, and the one
with the most value for unit tests, because every format can be checked
against sample files.

### Changes

- **Separate parsing from textures.** Sprite chunks (`SPR`, `SPR2`,
  `DGRP`) and `ImageLoader` return `Texture2D`. Have the library decode to
  a plain pixel buffer (for example `ReadOnlyMemory<byte>` plus width,
  height, and format) and let the rendering layer upload it. That removes
  MonoGame from the bottom of the dependency graph and lets servers and
  tools use the formats without a GPU.
- **Replace `IoBuffer`** with `BinaryPrimitives` over `ReadOnlySpan<byte>`
  or a small `ref struct` reader. It gives explicit endianness with no
  allocations, which matters for large FAR3 archives.
- **Chunk registry.** Replace the string-to-`Type` map and
  `Activator.CreateInstance` with a static table of factory delegates
  (`"BHAV" => static () => new Bhav()`). It's trimming- and AOT-friendly
  and checked at compile time.
- **Archives.** Open FAR3 with `RandomAccess.Read` on a `SafeFileHandle`
  so concurrent readers don't share a stream position, and drop the
  static `isReadingSomething` flag. Make archives `IDisposable` and
  required to dispose. A bad header should throw `InvalidDataException`.
- **Validation.** Check chunk sizes and offsets against the stream length
  before slicing. FreeSO's reader trusts the file, and a corrupt chunk can
  skip past the end.
- **Finalizer caching.** `IffFile` uses a finalizer to re-register itself
  with `TimedReferenceController`. Replace that with an explicit cache
  (for example `MemoryCache` with size limits) owned by the content layer.
- **Case-split folders.** Normalize folder names to one casing during the
  port. Linux checkouts otherwise create two folders.
- **Encoding.** `STR` uses language-specific code pages. On .NET 10,
  register `CodePagesEncodingProvider` before decoding non-UTF-8 text.
- **Tests.** Add xUnit tests per format with synthetic fixtures built in
  the test, not copied from the game, because the game files are EA's
  property.

### Sketch

```csharp
namespace FSO.Files.Iff;

public delegate IffChunk ChunkFactory();

public static class ChunkRegistry
{
    private static readonly FrozenDictionary<string, ChunkFactory> Factories =
        new Dictionary<string, ChunkFactory>
        {
            ["BHAV"] = static () => new Bhav(),
            ["OBJD"] = static () => new Objd(),
            // ...
        }.ToFrozenDictionary();

    public static bool TryCreate(string typeCode, [NotNullWhen(true)] out IffChunk? chunk)
    {
        chunk = Factories.TryGetValue(typeCode, out var factory) ? factory() : null;
        return chunk is not null;
    }
}
```

This is a sketch and has not been compiled.
