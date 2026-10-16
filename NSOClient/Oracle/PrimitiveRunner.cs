using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Nodes;
using FSO.SimAntics;
using FSO.SimAntics.Engine;

namespace FSO.Oracle
{
    /// <summary>
    /// Runs single 2017 primitives on request, for the Swift port's differential tests.
    /// </summary>
    /// <remarks>
    /// Reads one JSON request per line, skipping blank lines and lines starting with
    /// <c>#</c>, and writes one JSON response per line (protocol
    /// version 1, see README.md). Each request runs on a freshly loaded lot, so requests
    /// never see each other's effects. The primitive's handler is called directly, as
    /// <c>VMThread.ExecuteInstruction</c> calls it, on a one-instruction routine whose frame
    /// is pushed onto the caller's thread; the exit code is reported, not acted on.
    /// </remarks>
    public sealed class PrimitiveRunner
    {
        public const int ProtocolVersion = 1;

        /// <summary>BHAV operands are 8 bytes in every version the 2017 reader accepts.</summary>
        private const int OperandLength = 8;

        /// <summary>
        /// 2017 keeps entity attributes private (<c>VMEntity.Attributes</c>), and
        /// <c>GetAttribute</c> grows the list as a side effect, so snapshots read the list itself.
        /// </summary>
        private static readonly FieldInfo AttributesField =
            typeof(VMEntity).GetField("Attributes", BindingFlags.Instance | BindingFlags.NonPublic)
            ?? throw new InvalidOperationException("VMEntity.Attributes not found; the 2017 sources changed");

        /// <summary>Readable output: quotes and apostrophes in messages aren't escaped as \u0022.</summary>
        private static readonly JsonSerializerOptions JsonOptions = new() { Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping };

        private readonly Func<VM> loadLot;
        private readonly ulong defaultSeed;

        /// <param name="loadLot">Loads the lot every request starts from, the same way each time.</param>
        /// <param name="defaultSeed">The random seed for requests that don't give one.</param>
        public PrimitiveRunner(Func<VM> loadLot, ulong defaultSeed)
        {
            this.loadLot = loadLot;
            this.defaultSeed = defaultSeed;
        }

        /// <summary>Answers every request on <paramref name="input"/> until it ends.</summary>
        public void Run(TextReader input, TextWriter output)
        {
            string line;
            while ((line = input.ReadLine()) != null)
            {
                if (string.IsNullOrWhiteSpace(line) || line.StartsWith('#')) continue; // blank lines and comments
                output.WriteLine(Answer(line).ToJsonString(JsonOptions));
                output.Flush();
            }
        }

        /// <summary>Answers one request line. Never throws: problems are reported in the response.</summary>
        public JsonObject Answer(string line)
        {
            JsonNode id = null;
            Request request;
            try
            {
                var parsed = JsonNode.Parse(line) as JsonObject ?? throw new RequestException("a request must be a JSON object");
                id = parsed["id"]?.DeepClone();
                request = Request.Parse(parsed, defaultSeed);
            }
            catch (Exception error) when (error is RequestException || error is JsonException || error is FormatException)
            {
                return Response(id, "requestError", error.Message);
            }

            var vm = loadLot();
            try
            {
                return Execute(vm, request, id);
            }
            catch (RequestException error)
            {
                return Response(id, "requestError", error.Message);
            }
        }

        private static JsonObject Execute(VM vm, Request request, JsonNode id)
        {
            var primitive = vm.Context.Primitives[request.Opcode];
            var caller = request.Caller is short callerID
                ? vm.GetObjectById(callerID) ?? throw new RequestException($"no object {callerID} on the lot")
                : vm.Entities.OrderBy(entity => entity.ObjectID).FirstOrDefault() ?? throw new RequestException("the lot has no objects");
            if (caller.Thread == null) throw new RequestException($"object {caller.ObjectID} has no thread");
            if (request.StackObject != 0 && vm.GetObjectById(request.StackObject) == null)
                throw new RequestException($"no object {request.StackObject} on the lot");

            // Apply the requested state, then snapshot it, so the response holds only the primitive's effects.
            vm.Context.RandomSeed = request.Seed;
            if (request.Clock != null)
            {
                vm.Context.Clock.Hours = request.Clock.Value.Hours;
                vm.Context.Clock.Minutes = request.Clock.Value.Minutes;
                vm.Context.Clock.MinuteFractions = request.Clock.Value.MinuteFractions;
            }
            foreach (var (index, value) in request.Globals)
            {
                if (index >= vm.GlobalState.Length) throw new RequestException($"global {index} is out of range (0 to {vm.GlobalState.Length - 1})");
                vm.GlobalState[index] = value;
            }
            foreach (var (objectID, state) in request.Objects)
            {
                var entity = vm.GetObjectById(objectID) ?? throw new RequestException($"no object {objectID} on the lot");
                if (state.Direction is int direction)
                {
                    // Set the facing exactly: the setter snaps to the rotation step in object data 23.
                    var step = entity.ObjectData[23];
                    entity.ObjectData[23] = 0;
                    entity.Direction = (FSO.LotView.Model.Direction)(1 << direction);
                    entity.ObjectData[23] = step;
                }
                foreach (var (index, value) in state.Data)
                {
                    if (entity.ObjectData == null || index >= entity.ObjectData.Length)
                        throw new RequestException($"object data {index} is out of range for object {objectID}");
                    entity.ObjectData[index] = value;
                }
                foreach (var (index, value) in state.Attributes) entity.SetAttribute(index, value);
                if (state.List != null) entity.MyList = new LinkedList<short>(state.List);
            }
            var thread = caller.Thread;
            Array.Clear(thread.TempRegisters);
            request.Temps.CopyTo(thread.TempRegisters, 0);
            Array.Clear(thread.TempXL);
            request.TempXL.CopyTo(thread.TempXL, 0);

            var instruction = new VMInstruction { Opcode = request.Opcode, Index = 0, TruePointer = 254, FalsePointer = 255 };
            if (primitive?.OperandModel != null)
            {
                var operand = (VMPrimitiveOperand)Activator.CreateInstance(primitive.OperandModel);
                operand.Read(request.Operand);
                instruction.Operand = operand;
            }
            var routine = new VMRoutine
            {
                Instructions = new[] { instruction },
                Locals = (ushort)request.Locals.Length,
                Arguments = (ushort)request.Args.Length,
                ID = 4096,
                Rti = new VMFunctionRTI { Name = "fso-oracle request" },
            };
            instruction.Function = routine;
            var frame = new VMStackFrame
            {
                Thread = thread,
                Routine = routine,
                InstructionPointer = 0,
                Caller = caller,
                Callee = caller,
                CodeOwner = caller.Object,
                Locals = (short[])request.Locals.Clone(),
                Args = (short[])request.Args.Clone(),
            };
            frame.StackObjectID = request.StackObject;
            thread.Stack.Add(frame);

            var before = Snapshot.Take(vm);
            var response = Response(id, null, null);
            if (primitive == null)
            {
                // ExecuteInstruction treats an opcode with no primitive as GOTO_TRUE.
                response["exit"] = VMPrimitiveExitCode.GOTO_TRUE.ToString();
                response["noPrimitive"] = true;
            }
            else
            {
                response["primitive"] = primitive.Name;
                try
                {
                    response["exit"] = primitive.GetHandler().Execute(frame, instruction.Operand).ToString();
                }
                catch (Exception error)
                {
                    // 2017 lets this reach VMThread.Tick, which resets the thread.
                    response["exception"] = $"{error.GetType().Name}: {error.Message}";
                }
            }

            response["temps"] = Values(thread.TempRegisters);
            response["tempXL"] = Values(thread.TempXL);
            response["locals"] = Values(frame.Locals);
            response["args"] = Values(frame.Args);
            response["stackObject"] = frame.StackObjectID;
            response["callerGUID"] = caller.Object.OBJ.GUID.ToString("x8");
            var requestedStackObject = vm.GetObjectById(request.StackObject);
            if (requestedStackObject != null) response["stackObjectGUID"] = requestedStackObject.Object.OBJ.GUID.ToString("x8");
            response["seed"] = vm.Context.RandomSeed.ToString("x16");
            response["frames"] = thread.Stack.Count - thread.Stack.IndexOf(frame); // more than 1: the primitive pushed frames
            Snapshot.Take(vm).Describe(before, response);
            return response;
        }

        private static JsonObject Response(JsonNode id, string errorKey, string message)
        {
            var response = new JsonObject { ["protocol"] = ProtocolVersion };
            if (id != null) response["id"] = id;
            if (errorKey != null) response[errorKey] = message;
            return response;
        }

        private static JsonArray Values(IEnumerable<short> values) => new JsonArray(values.Select(value => (JsonNode)value).ToArray());

        private static JsonArray Values(IEnumerable<int> values) => new JsonArray(values.Select(value => (JsonNode)value).ToArray());

        /// <summary>A request the oracle can't run, reported to the caller instead of crashing.</summary>
        private sealed class RequestException : Exception
        {
            public RequestException(string message) : base(message) { }
        }

        /// <summary>A parsed and validated request.</summary>
        private sealed class Request
        {
            public ushort Opcode;
            public byte[] Operand;
            public short? Caller;
            public short StackObject;
            public ulong Seed;
            public short[] Temps;
            public int[] TempXL;
            public short[] Locals;
            public short[] Args;
            public List<(int Index, short Value)> Globals;
            public List<(short ObjectID, ObjectState State)> Objects;
            public (int Hours, int Minutes, int MinuteFractions)? Clock;

            public sealed class ObjectState
            {
                public List<(int Index, short Value)> Data;
                public List<(int Index, short Value)> Attributes;
                /// <summary>The whole list (<c>MyList</c>), front first, or null to leave it.</summary>
                public short[] List;
                /// <summary>The facing, 0 (north) to 7 clockwise, or null to leave it.</summary>
                public int? Direction;
            }

            public static Request Parse(JsonObject json, ulong defaultSeed)
            {
                var known = new HashSet<string> { "id", "opcode", "operand", "caller", "stackObject", "seed", "temps", "tempXL", "locals", "args", "globals", "objects", "clock" };
                foreach (var (key, _) in json)
                {
                    if (!known.Contains(key)) throw new RequestException($"unknown field \"{key}\"");
                }

                var opcode = Integer(json["opcode"] ?? throw new RequestException("\"opcode\" is required"), "opcode", 0, 255);
                return new Request
                {
                    Opcode = (ushort)opcode,
                    Operand = OperandBytes(json["operand"]),
                    Caller = json["caller"] is JsonNode caller ? (short)Integer(caller, "caller", 1, short.MaxValue) : null,
                    StackObject = json["stackObject"] is JsonNode stack ? (short)Integer(stack, "stackObject", short.MinValue, short.MaxValue) : (short)0,
                    Seed = json["seed"] is JsonNode seed ? Hex(seed, "seed") : defaultSeed,
                    Temps = Shorts(json["temps"], "temps", 20, 0),
                    TempXL = Ints(json["tempXL"], "tempXL", 2),
                    Locals = Shorts(json["locals"], "locals", byte.MaxValue, 0),
                    Args = Shorts(json["args"], "args", byte.MaxValue, 4),
                    Globals = Sparse(json["globals"], "globals"),
                    Objects = ObjectStates(json["objects"]),
                    Clock = ClockState(json["clock"]),
                };
            }

            /// <summary><c>{"hours": h, "minutes": m, "minuteFractions": f}</c>, each required.</summary>
            private static (int, int, int)? ClockState(JsonNode node)
            {
                if (node == null) return null;
                if (node is not JsonObject clock || clock.Count != 3)
                    throw new RequestException("\"clock\" must be an object with \"hours\", \"minutes\", and \"minuteFractions\"");
                return ((int)Integer(clock["hours"] ?? throw new RequestException("\"clock\" needs \"hours\""), "hours", 0, 23),
                        (int)Integer(clock["minutes"] ?? throw new RequestException("\"clock\" needs \"minutes\""), "minutes", 0, 59),
                        (int)Integer(clock["minuteFractions"] ?? throw new RequestException("\"clock\" needs \"minuteFractions\""), "minuteFractions", 0, 149));
            }

            private static long Integer(JsonNode node, string name, long minimum, long maximum)
            {
                if (node is not JsonValue value || !value.TryGetValue(out long number) || number < minimum || number > maximum)
                    throw new RequestException($"\"{name}\" must be an integer from {minimum} to {maximum}");
                return number;
            }

            private static ulong Hex(JsonNode node, string name)
            {
                if (node is JsonValue value && value.TryGetValue(out string text)
                    && ulong.TryParse(text, NumberStyles.AllowHexSpecifier, CultureInfo.InvariantCulture, out var number))
                    return number;
                throw new RequestException($"\"{name}\" must be a hexadecimal string");
            }

            /// <summary>Hex bytes, as stored in the BHAV; shorter operands are padded with zeros.</summary>
            private static byte[] OperandBytes(JsonNode node)
            {
                var bytes = new byte[OperandLength];
                if (node == null) return bytes;
                if (node is not JsonValue value || !value.TryGetValue(out string text) || text.Length % 2 != 0 || text.Length > OperandLength * 2)
                    throw new RequestException($"\"operand\" must be a hexadecimal string of up to {OperandLength} bytes");
                Convert.FromHexString(text).CopyTo(bytes, 0);
                return bytes;
            }

            private static short[] Shorts(JsonNode node, string name, int maximumCount, int defaultCount)
            {
                if (node == null) return new short[defaultCount];
                if (node is not JsonArray array || array.Count > maximumCount)
                    throw new RequestException($"\"{name}\" must be an array of at most {maximumCount} values");
                return array.Select(item => (short)Integer(item, name, short.MinValue, short.MaxValue)).ToArray();
            }

            private static int[] Ints(JsonNode node, string name, int maximumCount)
            {
                if (node == null) return Array.Empty<int>();
                if (node is not JsonArray array || array.Count > maximumCount)
                    throw new RequestException($"\"{name}\" must be an array of at most {maximumCount} values");
                return array.Select(item => (int)Integer(item, name, int.MinValue, int.MaxValue)).ToArray();
            }

            /// <summary>An object of index to value, such as <c>{"3": 10}</c>.</summary>
            private static List<(int, short)> Sparse(JsonNode node, string name)
            {
                if (node == null) return new List<(int, short)>();
                if (node is not JsonObject json) throw new RequestException($"\"{name}\" must be an object of index to value");
                return json.Select(pair => int.TryParse(pair.Key, NumberStyles.None, CultureInfo.InvariantCulture, out var index) && index <= 0xFFFF
                        ? (index, (short)Integer(pair.Value, name, short.MinValue, short.MaxValue))
                        : throw new RequestException($"\"{name}\" key \"{pair.Key}\" is not an index"))
                    .ToList();
            }

            private static List<(short, ObjectState)> ObjectStates(JsonNode node)
            {
                if (node == null) return new List<(short, ObjectState)>();
                if (node is not JsonObject json) throw new RequestException("\"objects\" must be an object of object ID to state");
                var states = new List<(short, ObjectState)>();
                foreach (var (key, value) in json)
                {
                    if (!short.TryParse(key, NumberStyles.None, CultureInfo.InvariantCulture, out var objectID) || objectID == 0)
                        throw new RequestException($"\"objects\" key \"{key}\" is not an object ID");
                    if (value is not JsonObject state || state.Any(pair => pair.Key != "data" && pair.Key != "attributes" && pair.Key != "list" && pair.Key != "direction"))
                        throw new RequestException($"object {key} state must be an object with \"data\", \"attributes\", and \"list\"");
                    states.Add((objectID, new ObjectState { Data = Sparse(state["data"], "data"), Attributes = Sparse(state["attributes"], "attributes"),
                        List = state["list"] == null ? null : Shorts(state["list"], "list", short.MaxValue, 0),
                        Direction = state["direction"] == null ? null : (int)Integer(state["direction"], "direction", 0, 7) }));
                }
                return states;
            }
        }

        /// <summary>The lot state a primitive can change outside its frame, for reporting the difference.</summary>
        private sealed class Snapshot
        {
            private short[] globals;
            private Dictionary<short, EntityState> entities;

            private sealed class EntityState
            {
                public short[] Data;
                public short[] Attributes;
                public short[] List;
                public short X, Y;
                public sbyte Level;
                public byte Direction;
            }

            public static Snapshot Take(VM vm) => new Snapshot
            {
                globals = (short[])vm.GlobalState.Clone(),
                entities = vm.Entities.ToDictionary(entity => entity.ObjectID, entity => new EntityState
                {
                    Data = (short[])entity.ObjectData?.Clone() ?? Array.Empty<short>(),
                    Attributes = ((List<short>)AttributesField.GetValue(entity))?.ToArray() ?? Array.Empty<short>(),
                    List = entity.MyList.ToArray(),
                    X = entity.Position.x,
                    Y = entity.Position.y,
                    Level = entity.Position.Level,
                    Direction = (byte)entity.Direction,
                }),
            };

            /// <summary>Adds what changed since <paramref name="before"/> to the response.</summary>
            public void Describe(Snapshot before, JsonObject response)
            {
                response["globals"] = Changes(before.globals, globals);
                var objects = new JsonObject();
                foreach (var (objectID, state) in entities.OrderBy(pair => pair.Key))
                {
                    if (!before.entities.TryGetValue(objectID, out var old)) continue;
                    var changes = new JsonObject();
                    var data = Changes(old.Data, state.Data);
                    if (data.Count > 0) changes["data"] = data;
                    var attributes = Changes(old.Attributes, state.Attributes);
                    if (attributes.Count > 0) changes["attributes"] = attributes;
                    if (!old.List.SequenceEqual(state.List)) changes["list"] = Values(state.List);
                    if (old.X != state.X || old.Y != state.Y || old.Level != state.Level)
                        changes["position"] = new JsonArray(state.X, state.Y, state.Level);
                    if (old.Direction != state.Direction) changes["direction"] = state.Direction;
                    if (changes.Count > 0) objects[objectID.ToString(CultureInfo.InvariantCulture)] = changes;
                }
                response["objects"] = objects;
                response["created"] = Values(entities.Keys.Except(before.entities.Keys).OrderBy(key => key));
                response["removed"] = Values(before.entities.Keys.Except(entities.Keys).OrderBy(key => key));
            }

            /// <summary>Indexes whose value changed; a list that grew reports its new entries, one that shrank reports 0.</summary>
            private static JsonObject Changes(short[] before, short[] after)
            {
                var changes = new JsonObject();
                for (var index = 0; index < Math.Max(before.Length, after.Length); index++)
                {
                    var old = index < before.Length ? before[index] : (short)0;
                    var value = index < after.Length ? after[index] : (short)0;
                    if (old != value) changes[index.ToString(CultureInfo.InvariantCulture)] = value;
                }
                return changes;
            }
        }
    }
}
