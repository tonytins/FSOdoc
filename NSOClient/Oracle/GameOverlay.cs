using System;
using System.Collections.Generic;
using System.IO;
using System.Xml.Linq;

namespace FSO.Oracle
{
    /// <summary>
    /// A temporary game folder: symbolic links to every file of a TSO install, plus empty
    /// placeholders for production files an older install (such as the 2002 beta) lacks.
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
        /// <summary>Production files the 2002 beta lacks (expansion sound groups and wall and floor archives), with placeholders.</summary>
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
            Mirror(installDirectory, root);

            var added = new List<string>();
            foreach (var (path, contents) in Placeholders)
            {
                var target = System.IO.Path.Combine(root, path);
                if (File.Exists(target)) continue;
                Directory.CreateDirectory(System.IO.Path.GetDirectoryName(target));
                File.WriteAllBytes(target, contents);
                added.Add($"the install has no {path}; using an empty placeholder");
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
