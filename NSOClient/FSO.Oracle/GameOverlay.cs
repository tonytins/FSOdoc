using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Xml.Linq;

namespace FSO.Oracle
{
    /// <summary>
    /// A temporary game folder: symbolic links to every file of a TSO install, plus empty
    /// placeholders for production files an older install (such as the 2002 beta) or a
    /// mock install (NSOClient/MockInstall) lacks.
    /// </summary>
    /// <remarks>
    /// FreeSO's content system loads some files unconditionally, such as every HIT sound
    /// group, and stops if one is missing. The oracle runs the VM without audio, so a
    /// placeholder is enough. Where an older install's file has a different shape, the
    /// overlay holds an adapted copy instead of the link. The install itself is never
    /// written to, and every placeholder and adaptation is reported.
    /// </remarks>
    public sealed class GameOverlay : IDisposable
    {
        /// <summary>Production files an install may lack, with placeholders: first what the 2002 beta lacks, then what a mock install does.</summary>
        private static readonly (string Path, byte[] Contents)[] Placeholders =
        {
            ("sounddata/relationships.hit", EmptyHIT()),
            ("sounddata/relationships.evt", Array.Empty<byte>()),
            ("sounddata/relationships.hsm", Array.Empty<byte>()),
            ("sounddata/tsov3.hit", EmptyHIT()),
            ("sounddata/tsov3.evt", Array.Empty<byte>()),
            ("sounddata/tsov3.hsm", Array.Empty<byte>()),
            ("sounddata/turkey.hit", EmptyHIT()),
            ("sounddata/turkey.evt", Array.Empty<byte>()),
            ("sounddata/turkey.hsm", Array.Empty<byte>()),
            ("housedata/walls2/walls2.far", EmptyFAR1()),
            ("housedata/walls3/walls3.far", EmptyFAR1()),
            ("housedata/walls4/walls4.far", EmptyFAR1()),
            ("housedata/floors2/floors2.far", EmptyFAR1()),
            ("housedata/floors3/floors3.far", EmptyFAR1()),
            ("housedata/floors4/floors4.far", EmptyFAR1()),
            // An install with only what NSOClient reads, such as NSOClient/MockInstall, lacks these too.
            ("tuning.dat", EmptyTuning()),
            ("TSOAudio.dat", AudioWithOneTrack()),
            ("tsov2.dat", DBPF()),
            ("Stings.dat", DBPF()),
            ("EP5Samps.dat", DBPF()),
            ("EP2.dat", DBPF()),
            ("HitListsTemp.dat", DBPF()),
            ("sounddata/newmain.hit", EmptyHIT()),
            ("sounddata/eventlist.txt", Array.Empty<byte>()),
            ("sounddata/newmain.hsm", Array.Empty<byte>()),
            ("sounddata/tsoep5.hit", EmptyHIT()),
            ("sounddata/tsoep5.evt", Array.Empty<byte>()),
            ("sounddata/tsoep5.hsm", Array.Empty<byte>()),
            ("sounddata/tsov2.hit", EmptyHIT()),
            ("sounddata/tsov2.evt", Array.Empty<byte>()),
            ("TSOData_datadefinition.dat", new byte[20]),  // a file ID, three empty lists, no strings
            ("objectdata/globals/walls.iff", IFF()),
            ("objectdata/globals/floors.iff", IFF()),
            ("objectdata/globals/build.iff", BuildGlobals()),
            ("housedata/walls/walls.far", EmptyFAR1()),
            ("housedata/floors/floors.far", EmptyFAR1()),
        };

        /// <summary>Folders FreeSO's content system lists at startup, created empty when missing.</summary>
        private static readonly string[] PlaceholderFolders =
        {
            "cities",
        };

        /// <summary>The overlay folder, with a trailing slash, to pass to FreeSO's content system.</summary>
        public string Path { get; }

        /// <summary>
        /// A scratch folder, with a trailing slash, for files FreeSO's code writes as user
        /// data (such as the sandbox ban list), so nothing is written into the repository.
        /// </summary>
        public string UserPath { get; }

        /// <summary>What the overlay added or adapted, one line each, for reporting.</summary>
        public IReadOnlyList<string> Changes { get; }

        public GameOverlay(string installDirectory)
        {
            var root = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "fso-oracle-" + Guid.NewGuid().ToString("N"));
            // Links must name absolute paths: a relative one would resolve from the overlay, not here.
            Mirror(System.IO.Path.GetFullPath(installDirectory), root);

            var added = new List<string>();
            foreach (var (path, contents) in Placeholders)
            {
                var target = System.IO.Path.Combine(root, path);
                if (File.Exists(target)) continue;
                Directory.CreateDirectory(System.IO.Path.GetDirectoryName(target));
                File.WriteAllBytes(target, contents);
                added.Add($"the install has no {path}; using an empty placeholder");
            }
            foreach (var path in PlaceholderFolders)
            {
                var target = System.IO.Path.Combine(root, path);
                if (Directory.Exists(target)) continue;
                Directory.CreateDirectory(target);
                added.Add($"the install has no {path}/; using an empty folder");
            }
            AdaptObjectTable(root, added);
            AdaptCatalog(root, added);

            Path = root + "/";
            UserPath = System.IO.Path.Combine(root, "fso-oracle-user") + "/";
            Directory.CreateDirectory(UserPath);
            Changes = added;
        }

        public void Dispose()
        {
            try
            {
                Directory.Delete(Path, recursive: true); // deletes the links, not what they point to
            }
            catch (IOException)
            {
                // Leaving a temporary folder behind is harmless.
            }
        }

        /// <summary>
        /// Recreates the folder tree with real directories and links each file, so
        /// placeholders can be added beside real files without touching the install.
        /// </summary>
        private static void Mirror(string source, string destination)
        {
            Directory.CreateDirectory(destination);
            foreach (var file in Directory.GetFiles(source))
            {
                File.CreateSymbolicLink(System.IO.Path.Combine(destination, System.IO.Path.GetFileName(file)), file);
            }
            foreach (var directory in Directory.GetDirectories(source))
            {
                Mirror(directory, System.IO.Path.Combine(destination, System.IO.Path.GetFileName(directory)));
            }
        }

        /// <summary>
        /// FreeSO's object provider reads each object's name from the `o` attribute of
        /// `packingslips/objecttable.xml`, which the 2002 beta's table lacks. The name is
        /// for display only, so the copy uses the object's file name (`n`).
        /// </summary>
        private static void AdaptObjectTable(string root, List<string> changes)
        {
            var path = System.IO.Path.Combine(root, "packingslips/objecttable.xml");
            if (!File.Exists(path)) return;
            var document = XDocument.Load(path);
            var adapted = 0;
            foreach (var entry in document.Descendants("I"))
            {
                if (entry.Attribute("o") != null) continue;
                entry.SetAttributeValue("o", (string)entry.Attribute("n") ?? "");
                adapted++;
            }
            if (adapted == 0) return;
            File.Delete(path); // the link, not the install's file
            document.Save(path);
            changes.Add($"packingslips/objecttable.xml has no object names (\"o\"); adapted a copy using file names for {adapted} objects");
        }

        /// <summary>
        /// FreeSO's catalog reads each entry's name from the `n` attribute of
        /// `packingslips/catalog.xml`, which the 2002 beta's catalog lacks. The copy takes
        /// the name from the object table entry with the same GUID.
        /// </summary>
        private static void AdaptCatalog(string root, List<string> changes)
        {
            var path = System.IO.Path.Combine(root, "packingslips/catalog.xml");
            var tablePath = System.IO.Path.Combine(root, "packingslips/objecttable.xml");
            if (!File.Exists(path)) return;

            var namesByGUID = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            if (File.Exists(tablePath))
            {
                foreach (var entry in XDocument.Load(tablePath).Descendants("I"))
                {
                    var guid = (string)entry.Attribute("g");
                    if (guid != null && !namesByGUID.ContainsKey(guid)) namesByGUID[guid] = (string)entry.Attribute("n") ?? "";
                }
            }

            var document = XDocument.Load(path);
            var adapted = 0;
            foreach (var entry in document.Descendants("P"))
            {
                if (entry.Attribute("n") != null) continue;
                var guid = (string)entry.Attribute("g") ?? "";
                entry.SetAttributeValue("n", namesByGUID.TryGetValue(guid, out var name) ? name : "");
                adapted++;
            }
            if (adapted == 0) return;
            File.Delete(path); // the link, not the install's file
            document.Save(path);
            changes.Add($"packingslips/catalog.xml has no names (\"n\"); adapted a copy using object table names for {adapted} entries");
        }

        /// <summary>
        /// A `tuning.dat` with no entries: a Persist header, then the entry count. FreeSO's
        /// RefPack reader returns input of 6 bytes or fewer unchanged, so the 4-byte count needs
        /// no compression.
        /// </summary>
        private static byte[] EmptyTuning()
        {
            using var stream = new MemoryStream();
            using (var writer = new BinaryWriter(stream))
            {
                writer.Write((byte)1);         // body type
                writer.Write(4u);              // decompressed size
                writer.Write(4u);              // compressed size
                writer.Write(4u);              // stream body size
                writer.Write((ushort)0xFB10);  // RefPack
                writer.Write(new byte[] { 0, 0, 4 });
                writer.Write(0u);              // no entries
            }
            return stream.ToArray();
        }

        /// <summary>
        /// A version 1.0 DBPF archive: a 96-byte header, each entry's data, then the index (type,
        /// group, instance, offset, and size for each).
        /// </summary>
        private static byte[] DBPF(params (uint Type, uint Instance, byte[] Data)[] entries)
        {
            using var stream = new MemoryStream();
            using (var writer = new BinaryWriter(stream))
            {
                var offsets = new List<uint>();
                writer.Write(new byte[96]);
                foreach (var entry in entries)
                {
                    offsets.Add((uint)stream.Position);
                    writer.Write(entry.Data);
                }
                var indexOffset = (uint)stream.Position;
                for (var i = 0; i < entries.Length; i++)
                {
                    writer.Write(entries[i].Type);
                    writer.Write(0u);                       // group
                    writer.Write(entries[i].Instance);
                    writer.Write(offsets[i]);
                    writer.Write((uint)entries[i].Data.Length);
                }
                stream.Position = 0;
                writer.Write("DBPF".ToCharArray());
                writer.Write(1u);                           // major version
                writer.Write(0u);                           // minor version
                writer.Write(new byte[12]);
                writer.Write(0);                            // created
                writer.Write(0);                            // modified
                writer.Write(7u);                           // index major version
                writer.Write((uint)entries.Length);
                writer.Write(indexOffset);
                writer.Write((uint)(entries.Length * 20));  // index size
            }
            return stream.ToArray();
        }

        /// <summary>
        /// The audio archive with one silent track, since FreeSO's audio loader fails on an archive
        /// with no tracks at all.
        /// </summary>
        private static byte[] AudioWithOneTrack() =>
            DBPF((0x5D73A611, 1, System.Text.Encoding.ASCII.GetBytes("TKDT,1,mock,0,0,")));

        /// <summary>A FAR version 1 archive with no files.</summary>
        private static byte[] EmptyFAR1()
        {
            using var stream = new MemoryStream();
            using (var writer = new BinaryWriter(stream))
            {
                writer.Write("FAR!byAZ".ToCharArray());
                writer.Write(1u);  // version
                writer.Write(16u); // manifest offset: right after this header
                writer.Write(0u);  // file count
            }
            return stream.ToArray();
        }

        /// <summary>
        /// The build mode string tables FreeSO's wall and floor providers read: wall style
        /// names (0x81, five priced entries, one per buyable style), no wall or floor
        /// patterns (0x83), and the two pools (0x85).
        /// </summary>
        private static byte[] BuildGlobals()
        {
            string[] Priced(int count) => Enumerable.Range(0, count)
                .SelectMany(i => new[] { "0", $"mock {i}", "" }).ToArray();
            return IFF(("STR#", 0x81, STR(Priced(5))), ("STR#", 0x83, STR()), ("STR#", 0x85, STR(Priced(2))));
        }

        /// <summary>An STR# chunk in format 0xFFFF: a count, then null-terminated strings.</summary>
        private static byte[] STR(params string[] strings)
        {
            using var stream = new MemoryStream();
            using (var writer = new BinaryWriter(stream))
            {
                writer.Write((short)-1);
                writer.Write((ushort)strings.Length);
                foreach (var text in strings)
                {
                    writer.Write(System.Text.Encoding.UTF8.GetBytes(text));
                    writer.Write((byte)0);
                }
            }
            return stream.ToArray();
        }

        /// <summary>An IFF 2.5 file of the given chunks, with no resource map.</summary>
        private static byte[] IFF(params (string Type, ushort ID, byte[] Data)[] chunks)
        {
            using var stream = new MemoryStream();
            void BigEndian(uint value, int bytes)
            {
                for (var shift = (bytes - 1) * 8; shift >= 0; shift -= 8) stream.WriteByte((byte)(value >> shift));
            }
            var header = new byte[60];
            System.Text.Encoding.ASCII.GetBytes("IFF FILE 2.5:TYPE FOLLOWED BY SIZE\0 JAMIE DOORNBOS & MAXIS 1").CopyTo(header, 0);
            stream.Write(header);
            BigEndian(0, 4);  // resource map offset: none
            foreach (var chunk in chunks)
            {
                stream.Write(System.Text.Encoding.ASCII.GetBytes(chunk.Type));
                BigEndian((uint)(chunk.Data.Length + 76), 4);
                BigEndian(chunk.ID, 2);
                BigEndian(0, 2);  // flags
                stream.Write(new byte[64]);  // label
                stream.Write(chunk.Data);
            }
            return stream.ToArray();
        }

        /// <summary>The smallest HIT file FreeSO's reader accepts: a header with no entry table.</summary>
        private static byte[] EmptyHIT()
        {
            using var stream = new MemoryStream();
            using (var writer = new BinaryWriter(stream))
            {
                writer.Write("HIT!".ToCharArray());
                writer.Write(1u); // major version
                writer.Write(0u); // minor version
                writer.Write("TRAX".ToCharArray());
            }
            return stream.ToArray();
        }
    }
}
