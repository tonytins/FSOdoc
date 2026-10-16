using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Xml.Linq;
using FSO.Common;
using FSO.SimAntics;
using FSO.SimAntics.Engine;
using FSO.SimAntics.Engine.TSOTransaction;
using FSO.SimAntics.Model;
using FSO.SimAntics.NetPlay.Drivers;
using FSO.SimAntics.NetPlay.Model.Commands;

namespace FSO.Oracle
{
    /// <summary>
    /// Runs FreeSO's SimAntics VM headless and prints reference results for the Swift port.
    /// </summary>
    public static class Program
    {
        private const string Usage = @"usage: fso-oracle run-lot [options] [--ticks N] [--every N]
       fso-oracle run-primitive [options]
       fso-oracle list-objects [options]
       fso-oracle run-objects [options] [--ticks N] [--every N]
       fso-oracle room-maps [options]

run-lot loads a lot from blueprint XML into a headless FreeSO VM, as FreeSO's lot
server does, ticks it, and prints a state digest.

run-primitive loads the same lot, then reads JSON requests from standard input, one
per line, runs each FreeSO primitive on a fresh copy of the lot, and writes one JSON
response per line (see README.md).

run-objects reads object GUIDs (hexadecimal) from standard input, one per line. For each,
it loads an empty lot, creates the object out of the world, and prints a state digest
after creation and as it ticks (see README.md).

room-maps reads blueprint XML paths from standard input, one per line, loads each lot,
and prints its room map and rooms as one JSON line (see README.md).

list-objects loads every registered object through FreeSO's content system and prints
one tab-separated line per object (see README.md).

Standard output carries only results; FreeSO's own messages go to standard error.

options:
  --game DIR        the TSO install (default: $TSO_GAME_DIR)
  --content DIR     FreeSO's Content folder, for patches and blueprints
                    (default: TSOClient/tso.content/Content in this repository)
  --blueprint FILE  lot XML (default: Blueprints/empty_lot_fso.xml in the content folder)
  --seed HEX        the VM's random seed once the lot is loaded (default: 0F50D0C5EED00001)
  --ticks N         run-lot and run-objects: ticks to run after loading (default: 1800, one minute of game time)
  --every N         run-lot and run-objects: also print a digest every N ticks (default: 0, only at the end)";

        public static int Main(string[] args)
        {
            if (args.Length == 0 || !new[] { "run-lot", "run-primitive", "list-objects", "run-objects", "room-maps" }.Contains(args[0]))
            {
                Console.Error.WriteLine(Usage);
                return 2;
            }

            Options options;
            try
            {
                options = Options.Parse(args.Skip(1).ToArray());
            }
            catch (ArgumentException error)
            {
                Console.Error.WriteLine($"fso-oracle: {error.Message}\n\n{Usage}");
                return 2;
            }

            // FreeSO's code writes diagnostics to standard output; keep that for results only.
            var results = Console.Out;
            Console.SetOut(Console.Error);

            // Content: the game files (through an overlay that fills in files older installs lack),
            // plus FreeSO's own folder for patches and standalone objects.
            using var overlay = new GameOverlay(options.GameDirectory);
            foreach (var change in overlay.Changes)
                Console.Error.WriteLine($"fso-oracle: {change}");
            FSOEnvironment.ContentDir = options.ContentDirectory;
            FSOEnvironment.UserDir = overlay.UserPath;
            Content.Content.Init(overlay.Path, Content.ContentMode.SERVER);
            if (args[0] == "list-objects")
            {
                ListObjects(results);
                return 0;
            }
            if (args[0] == "room-maps")
            {
                RoomMaps(options, results);
                return 0;
            }
            var blueprint = BlueprintForInstall(options.BlueprintPath);

            if (args[0] == "run-objects")
            {
                RunObjects(EmptyBlueprint(blueprint), options, results);
                return 0;
            }
            if (args[0] == "run-lot")
            {
                RunLot(LoadLot(blueprint, options.Seed), options, results);
            }
            else
            {
                new PrimitiveRunner(() => LoadLot(blueprint, options.Seed), options.Seed).Run(Console.In, results);
            }
            return 0;
        }

        private static VM LoadLot(byte[] blueprint, ulong seed)
        {
            // The VM, built the way LotContainer.ResetVM builds it on the lot server.
            VM.UseWorld = false;
            var driver = new VMServerDriver(new VMTSOGlobalLinkStub());
            // FreeSO seeds the VM from an unseeded Random. A fixed seed makes runs repeatable;
            // in multiplayer the server's seed is authoritative in the same way.
            var context = new VMContext(null) { RandomSeed = seed };
            var vm = new VM(context, driver, new VMNullHeadlineProvider());
            vm.Init();

            // Load the lot the way LotContainer.BlueprintReset does.
            vm.SendCommand(new VMBlueprintRestoreCmd
            {
                JobLevel = -1,
                XMLData = blueprint,
            });
            vm.Tick();
            // Loading replaces the VM's context (VMWorldActivator.LoadFromXML), which reseeds
            // itself from an unseeded Random. Seed it again once the lot is loaded.
            vm.Context.RandomSeed = seed;
            return vm;
        }

        /// <summary>The blueprint with every object taken out: the same lot, empty.</summary>
        private static byte[] EmptyBlueprint(byte[] blueprint)
        {
            var document = XDocument.Load(new MemoryStream(blueprint));
            document.Descendants("object").Remove();
            using var stream = new MemoryStream();
            document.Save(stream);
            return stream.ToArray();
        }

        /// <summary>
        /// For each GUID on standard input: an empty lot, the object created out of the world as
        /// <c>VMContext.CreateObjectInstance</c> does (running its init), then ticks. Prints
        /// <c>guid tick N seed S entities E digest D</c> after creation (tick 0), every
        /// <c>--every</c> ticks, and at the end; or <c>guid missing</c> if the object can't be
        /// created, or <c>guid error Type</c> if creating or ticking throws.
        /// </summary>
        private static void RunObjects(byte[] emptyBlueprint, Options options, TextWriter results)
        {
            string line;
            while ((line = Console.In.ReadLine()) != null)
            {
                line = line.Trim();
                if (line.Length == 0) continue;
                if (!uint.TryParse(line, System.Globalization.NumberStyles.HexNumber, null, out var guid))
                {
                    results.WriteLine($"{line} error not a GUID");
                    continue;
                }
                var prefix = guid.ToString("x8");
                try
                {
                    var vm = LoadLot(emptyBlueprint, options.Seed);
                    var group = vm.Context.CreateObjectInstance(guid, FSO.LotView.Model.LotTilePos.OUT_OF_WORLD, FSO.LotView.Model.Direction.NORTH);
                    if (group == null)
                    {
                        results.WriteLine($"{prefix} missing");
                        continue;
                    }
                    PrintDigest(vm, 0, results, prefix + " ");
                    for (var tick = 1; tick <= options.Ticks; tick++)
                    {
                        vm.Tick();
                        if ((options.Every > 0 && tick % options.Every == 0) || tick == options.Ticks) PrintDigest(vm, tick, results, prefix + " ");
                    }
                }
                catch (Exception error)
                {
                    results.WriteLine($"{prefix} error {error.GetType().Name}");
                    Console.Error.WriteLine($"fso-oracle: object {prefix}: {error}");
                }
                results.Flush();
            }
        }

        /// <summary>
        /// For each blueprint path on standard input: the lot loaded as <see cref="LoadLot"/> loads
        /// it, then one JSON line with its room map and rooms (see README.md), or
        /// <c>{"file":…,"error":Type}</c> if loading throws.
        /// </summary>
        private static void RoomMaps(Options options, TextWriter results)
        {
            string line;
            while ((line = Console.In.ReadLine()) != null)
            {
                line = line.Trim();
                if (line.Length == 0) continue;
                var output = new System.Text.Json.Nodes.JsonObject { ["file"] = Path.GetFileName(line) };
                try
                {
                    var architecture = LoadLot(BlueprintForInstall(line), options.Seed).Context.Architecture;
                    output["size"] = new System.Text.Json.Nodes.JsonArray(architecture.Width, architecture.Height);
                    var maps = new System.Text.Json.Nodes.JsonArray();
                    foreach (var level in architecture.Rooms)
                        maps.Add(new System.Text.Json.Nodes.JsonArray(level.Map.Select(entry => (System.Text.Json.Nodes.JsonNode)entry).ToArray()));
                    output["maps"] = maps;
                    var rooms = new System.Text.Json.Nodes.JsonArray();
                    foreach (var room in architecture.RoomData.Skip(1))
                    {
                        rooms.Add(new System.Text.Json.Nodes.JsonArray(
                            room.RoomID, room.LightBaseRoom, room.Floor, room.IsOutside, room.Area, room.IsPool,
                            Numbers(room.AdjRooms),
                            new System.Text.Json.Nodes.JsonArray(room.Bounds.X, room.Bounds.Y, room.Bounds.Width, room.Bounds.Height),
                            Numbers(room.SupportRooms)));
                    }
                    output["rooms"] = rooms;
                }
                catch (Exception error)
                {
                    output["error"] = error.GetType().Name;
                    Console.Error.WriteLine($"fso-oracle: blueprint {line}: {error}");
                }
                results.WriteLine(output.ToJsonString());
                results.Flush();
            }

            static System.Text.Json.Nodes.JsonArray Numbers(IEnumerable<ushort> values) =>
                new System.Text.Json.Nodes.JsonArray(values.Select(value => (System.Text.Json.Nodes.JsonNode)value).ToArray());
        }

        private static void RunLot(VM vm, Options options, TextWriter results)
        {
            PrintDigest(vm, 0, results);

            for (var tick = 1; tick <= options.Ticks; tick++)
            {
                vm.Tick();
                if (options.Every > 0 && tick % options.Every == 0 && tick != options.Ticks) PrintDigest(vm, tick, results);
            }
            if (options.Ticks > 0) PrintDigest(vm, options.Ticks, results);
        }

        /// <summary>
        /// Prints what FreeSO's content system loads for every registered object, for the
        /// Swift content tests to compare against.
        /// </summary>
        /// <remarks>
        /// One line per GUID registered at startup, sorted by GUID, tab-separated: the GUID
        /// (8 hex digits), then either the OBJD label, the resource name, the semi-global
        /// (lower-case file name without extension, or <c>-</c>), the number of routines by
        /// name, the number of BHAVs, the number of tuning tables, and the entry point table
        /// (see <see cref="EntryPoints"/>); or <c>missing</c> if no
        /// OBJD has the GUID; or <c>error</c> and the exception type if loading fails.
        /// Loading can register objects again (patched files), so the GUIDs are taken first.
        /// </remarks>
        private static void ListObjects(TextWriter results)
        {
            var provider = Content.Content.Get().WorldObjects;
            List<ulong> guids;
            lock (provider.Entries) guids = provider.Entries.Keys.OrderBy(guid => guid).ToList();
            foreach (var guid in guids)
            {
                string line;
                try
                {
                    var item = provider.Get(guid);
                    if (item == null)
                    {
                        line = "missing";
                    }
                    else
                    {
                        var resource = item.Resource;
                        var semiGlobal = resource.SemiGlobal?.Iff?.Filename;
                        line = string.Join("\t",
                            item.OBJ.ChunkLabel,
                            resource.Name,
                            semiGlobal == null ? "-" : Path.GetFileNameWithoutExtension(semiGlobal).ToLowerInvariant(),
                            resource.TreeByName.Count,
                            resource.MainIff.List<Files.Formats.IFF.Chunks.BHAV>()?.Count ?? 0,
                            resource.Tuning?.Tables?.Length ?? 0,
                            EntryPoints(item));
                    }
                }
                catch (Exception error)
                {
                    line = "error\t" + error.GetType().Name;
                    Console.Error.WriteLine($"fso-oracle: object {guid:x8}: {error}");
                }
                results.WriteLine($"{guid:x8}\t{line}");
            }
        }

        /// <summary>
        /// The entry point table a FreeSO entity builds for an object: each entry as
        /// <c>condition:action</c>, comma-separated, or <c>none</c> without a table, or
        /// <c>error</c> and the exception type if building the entity fails.
        /// </summary>
        private static string EntryPoints(Content.GameObject item)
        {
            try
            {
                var entity = new VMGameObject(item, null);
                return entity.EntryPoints == null ? "none"
                    : string.Join(",", entity.EntryPoints.Select(entry => $"{entry.ConditionFunction}:{entry.ActionFunction}"));
            }
            catch (Exception error)
            {
                return "error " + error.GetType().Name;
            }
        }

        /// <summary>
        /// Reads blueprint XML, dropping objects the install doesn't have.
        /// </summary>
        /// <remarks>
        /// FreeSO's blueprints assume TSO's 2003 production files. On an older install
        /// (such as the 2002 beta) some objects don't exist, and FreeSO's activator fails
        /// on a missing object, so they're left out and reported. The Swift side must load
        /// the same adapted lot.
        /// </remarks>
        private static byte[] BlueprintForInstall(string path)
        {
            var document = XDocument.Load(path);
            var objects = Content.Content.Get().WorldObjects;
            var missing = document.Descendants("object")
                .Where(element => objects.Get(Convert.ToUInt32((string)element.Attribute("guid"), 16)) == null)
                .ToList();
            foreach (var element in missing)
            {
                Console.Error.WriteLine($"fso-oracle: the install has no object {(string)element.Attribute("guid")}; left out of the lot");
                element.Remove();
            }
            using var stream = new MemoryStream();
            document.Save(stream);
            return stream.ToArray();
        }

        /// <summary>
        /// Prints a digest of the VM state that the Swift port can compute the same way.
        /// </summary>
        /// <remarks>
        /// Digest version 0, SHA-256 over little-endian values, in this order: the random
        /// seed; the entity count; then for each entity in object ID order: object ID, GUID,
        /// tile x, tile y, level, direction, the object data count and values, and the
        /// thread's stack depth, then each frame's routine ID and instruction pointer.
        /// </remarks>
        private static void PrintDigest(VM vm, int tick, TextWriter results, string prefix = "")
        {
            using var stream = new MemoryStream();
            using (var writer = new BinaryWriter(stream, Encoding.UTF8, leaveOpen: true))
            {
                writer.Write(vm.Context.RandomSeed);
                var entities = vm.Entities.OrderBy(entity => entity.ObjectID).ToList();
                writer.Write(entities.Count);
                foreach (var entity in entities)
                {
                    writer.Write(entity.ObjectID);
                    writer.Write(entity.Object?.OBJ?.GUID ?? 0u);
                    writer.Write(entity.Position.x);
                    writer.Write(entity.Position.y);
                    writer.Write(entity.Position.Level);
                    writer.Write((byte)entity.Direction);
                    var data = entity.ObjectData ?? Array.Empty<short>();
                    writer.Write(data.Length);
                    foreach (var value in data) writer.Write(value);
                    var stack = entity.Thread?.Stack ?? new List<VMStackFrame>();
                    writer.Write(stack.Count);
                    foreach (var frame in stack)
                    {
                        writer.Write(frame.Routine?.ID ?? (ushort)0);
                        writer.Write(frame.InstructionPointer);
                    }
                }
            }
            var digest = Convert.ToHexString(SHA256.HashData(stream.ToArray())).ToLowerInvariant();
            results.WriteLine($"{prefix}tick {tick} seed {vm.Context.RandomSeed:x16} entities {vm.Entities.Count} digest {digest}");
        }

        private sealed class Options
        {
            public string GameDirectory;
            public string ContentDirectory;
            public string BlueprintPath;
            public int Ticks = 1800;
            public int Every;
            public ulong Seed = 0x0F50_D0C5_EED0_0001;

            public static Options Parse(string[] args)
            {
                var repository = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "../../../../.."));
                var options = new Options
                {
                    GameDirectory = Environment.GetEnvironmentVariable("TSO_GAME_DIR"),
                    ContentDirectory = Path.Combine(repository, "TSOClient/tso.content/Content"),
                };

                for (var index = 0; index < args.Length; index++)
                {
                    string Value() => index + 1 < args.Length
                        ? args[++index]
                        : throw new ArgumentException($"{args[index]} needs a value");
                    int Count() => int.TryParse(Value(), out var count) && count >= 0
                        ? count
                        : throw new ArgumentException($"{args[index - 1]} takes a number of 0 or more");

                    switch (args[index])
                    {
                        case "--game": options.GameDirectory = Value(); break;
                        case "--content": options.ContentDirectory = Value(); break;
                        case "--blueprint": options.BlueprintPath = Value(); break;
                        case "--ticks": options.Ticks = Count(); break;
                        case "--every": options.Every = Count(); break;
                        case "--seed":
                            options.Seed = ulong.TryParse(Value(), System.Globalization.NumberStyles.HexNumber, null, out var seed)
                                ? seed
                                : throw new ArgumentException("--seed takes a hexadecimal number");
                            break;
                        default: throw new ArgumentException($"unknown option {args[index]}");
                    }
                }

                if (string.IsNullOrEmpty(options.GameDirectory))
                    throw new ArgumentException("no --game given and TSO_GAME_DIR is not set");
                if (!Directory.Exists(options.GameDirectory))
                    throw new ArgumentException($"{options.GameDirectory} does not exist");
                if (!Directory.Exists(options.ContentDirectory))
                    throw new ArgumentException($"{options.ContentDirectory} does not exist");

                // FreeSO joins content paths by string concatenation, so these need a trailing slash.
                options.GameDirectory = WithTrailingSlash(options.GameDirectory);
                options.ContentDirectory = WithTrailingSlash(options.ContentDirectory);
                options.BlueprintPath ??= Path.Combine(options.ContentDirectory, "Blueprints/empty_lot_fso.xml");
                if (!File.Exists(options.BlueprintPath))
                    throw new ArgumentException($"{options.BlueprintPath} does not exist");
                return options;
            }

            private static string WithTrailingSlash(string path) =>
                path.EndsWith("/", StringComparison.Ordinal) ? path : path + "/";
        }
    }
}
