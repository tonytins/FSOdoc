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
    /// Runs the 2017 SimAntics VM headless and prints reference results for the Swift port.
    /// </summary>
    public static class Program
    {
        private const string Usage = @"usage: fso-oracle run-lot [--game DIR] [--content DIR] [--blueprint FILE] [--ticks N] [--every N] [--seed HEX]

Loads a lot from blueprint XML into a headless 2017 VM, as FreeSO's lot server does,
ticks it, and prints a state digest.

  --game DIR        the TSO install (default: $TSO_GAME_DIR)
  --content DIR     FreeSO's Content folder, for patches and blueprints
                    (default: TSOClient/tso.content/Content in this repository)
  --blueprint FILE  lot XML (default: Blueprints/empty_lot_fso.xml in the content folder)
  --ticks N         ticks to run after loading (default: 1800, one minute of game time)
  --every N         also print a digest every N ticks (default: 0, only at the end)
  --seed HEX        the VM's initial random seed (default: 0F50D0C5EED00001)";

        public static int Main(string[] args)
        {
            if (args.Length == 0 || args[0] != "run-lot")
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

            RunLot(options);
            return 0;
        }

        private static void RunLot(Options options)
        {
            // Content: the game files (through an overlay that fills in files older installs lack),
            // plus FreeSO's own folder for patches and standalone objects.
            using var overlay = new GameOverlay(options.GameDirectory);
            foreach (var change in overlay.Changes)
                Console.Error.WriteLine($"fso-oracle: {change}");
            FSOEnvironment.ContentDir = options.ContentDirectory;
            FSOEnvironment.UserDir = overlay.UserPath;
            Content.Content.Init(overlay.Path, Content.ContentMode.SERVER);

            // The VM, built the way LotContainer.ResetVM builds it on the lot server.
            VM.UseWorld = false;
            var driver = new VMServerDriver(new VMTSOGlobalLinkStub());
            // 2017 seeds the VM from an unseeded Random. A fixed seed makes runs repeatable;
            // in multiplayer the server's seed is authoritative in the same way.
            var context = new VMContext(null) { RandomSeed = options.Seed };
            var vm = new VM(context, driver, new VMNullHeadlineProvider());
            vm.Init();

            // Load the lot the way LotContainer.BlueprintReset does.
            vm.SendCommand(new VMBlueprintRestoreCmd
            {
                JobLevel = -1,
                XMLData = BlueprintForInstall(options.BlueprintPath),
            });
            vm.Tick();
            // Loading replaces the VM's context (VMWorldActivator.LoadFromXML), which reseeds
            // itself from an unseeded Random. Seed it again once the lot is loaded.
            vm.Context.RandomSeed = options.Seed;
            PrintDigest(vm, 0);

            for (var tick = 1; tick <= options.Ticks; tick++)
            {
                vm.Tick();
                if (options.Every > 0 && tick % options.Every == 0 && tick != options.Ticks) PrintDigest(vm, tick);
            }
            if (options.Ticks > 0) PrintDigest(vm, options.Ticks);
        }

        /// <summary>
        /// Reads blueprint XML, dropping objects the install doesn't have.
        /// </summary>
        /// <remarks>
        /// FreeSO's blueprints assume TSO's 2003 production files. On an older install
        /// (such as the 2002 beta) some objects don't exist, and the 2017 activator fails
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
        private static void PrintDigest(VM vm, int tick)
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
            Console.WriteLine($"tick {tick} seed {vm.Context.RandomSeed:x16} entities {vm.Entities.Count} digest {digest}");
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

                // 2017 joins content paths by string concatenation, so these need a trailing slash.
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
