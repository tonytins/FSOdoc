using FSO.Server.Framework.Gluon;
using FSO.Server.Protocol.Gluon.Model;
using FSO.Server.Protocol.Gluon.Packets;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FSO.Server.Servers.City.Domain
{
    public class LotServerPicker
    {
        private List<LotServerState> Servers = new List<LotServerState>();
        private Dictionary<string, LotServerState> ServersByCallsign = new Dictionary<string, LotServerState>();
        private TaskCompletionSource<bool> AllServersShutdown;
        private HashSet<IGluonSession> ServersShutdown;

        public Task<object> Pick(uint claimId)
        {
            return null;
        }

        /// <summary>
        /// Picks a server to perform a lot picking attempt.
        /// </summary>
        /// <returns>A <see cref="LotPickerAttempt"/> object representing the attempt result.</returns>
        public LotPickerAttempt PickServer()
        {
            lock (Servers)
            {
                var best = Servers.OrderByDescending(x => x.Rank).FirstOrDefault();
                if (best == null || best.Rank <= 0)
                {
                    return new LotPickerAttempt(null) { Success = false };
                }

                var attempt = new LotPickerAttempt(best) { Success = true };
                best.InFlight.Add(attempt);
                return attempt;
            }
        }

        /// <summary>
        /// Retrieves the session of a lot server with the specified call sign.
        /// </summary>
        /// <param name="callSign">The call sign of the lot server.</param>
        /// <returns>The session of the lot server, or null if not found.</returns>
        public IGluonSession GetLotServerSession(string callSign)
        {
            lock (Servers)
            {
                IGluonSession result = null;
                LotServerState state = null;
                if (ServersByCallsign.TryGetValue(callSign, out state)) result = state.Session;
                return result;
            }
        }

        /// <summary>
        /// Shuts down all lot servers with the specified shutdown type.
        /// </summary>
        /// <param name="type">The type of shutdown to perform.</param>
        /// <returns>A <see cref="Task"/> representing the asynchronous shutdown operation.</returns>
        public async Task<bool> ShutdownAllLotServers(ShutdownType type)
        {
            if (AllServersShutdown != null) return false;
            AllServersShutdown = new TaskCompletionSource<bool>();
            ServersShutdown = new HashSet<IGluonSession>();
            lock (Servers)
            {
                lock (ServersShutdown)
                {
                    foreach (var server in Servers)
                    {
                        var s = server.Session;
                        ServersShutdown.Add(s);
                        s.Write(new ShardShutdownRequest
                        {
                            ShardId = 0,
                            Type = type
                        });
                    }
                }
            }
            return await AllServersShutdown.Task;
        }

        /// <summary>
        /// Registers a lot server session for shutdown.
        /// </summary>
        /// <param name="session">The session to register for shutdown.</param>
        public void RegisterShutdown(IGluonSession session)
        {
            lock (ServersShutdown)
            {
                ServersShutdown.Remove(session);
                if (ServersShutdown.Count == 0) AllServersShutdown.SetResult(true);
            }
        }
    }

    /// <summary>
    /// Updates the server advertisement with the provided capacity information for the given session.
    /// </summary>
    /// <param name="session">The Gluon session to update.</param>
    /// <param name="request">The capacity advertisement request.</param>
    public void UpdateServerAdvertisement(IGluonSession session, AdvertiseCapacity request)
    {
        lock (Servers)
        {
            var state = GetState(session);
            if (state == null)
            {
                state = new LotServerState
                {
                    Session = session
                };
                Servers.Add(state);
                if (ServersByCallsign.ContainsKey(session.CallSign))
                {
                    ServersByCallsign[session.CallSign] = state;
                }
                else
                {
                    ServersByCallsign.Add(session.CallSign, state);
                }
            }
            state.Session = session; // can be hot-swapped if we re-establish connection. TODO: verify and look for race conditions
            state.MaxLots = request.MaxLots;
            state.CurrentLots = request.CurrentLots;
            state.CpuPercentAvg = request.CpuPercentAvg;
            state.RamAvaliable = request.RamAvaliable;
            state.RamUsed = request.RamUsed;
        }
    }

    /// <summary>
    /// Retrieves the LotServerState associated with the given Gluon session.
    /// </summary>
    /// <param name="session">The Gluon session to get the LotServerState for.</param>
    /// <returns>The LotServerState associated with the given Gluon session, or null if not found.</returns>
    private LotServerState GetState(IGluonSession session)
    {
        var server = Servers.FirstOrDefault(x => x.Session == session);
        return server;
    }
}

/// <summary>
/// Represents the state of a lot server.
/// </summary>
public class LotServerState
{
    /// <summary>
    /// Gets or sets the Gluon session associated with this lot server state.
    /// </summary>
    public IGluonSession Session;

    /// <summary>
    /// Gets or sets the list of lot picker attempts that are currently in flight for this lot server.
    /// </summary>
    public List<LotPickerAttempt> InFlight = new List<LotPickerAttempt>();

    /// <summary>
    /// Gets or sets the maximum number of lots that this lot server can handle.
    /// </summary>
    public short MaxLots;

    /// <summary>
    /// Gets or sets the current number of lots that this lot server has.
    /// </summary>
    public short CurrentLots;

    /// <summary>
    /// Gets or sets the average CPU usage percentage for this lot server.
    /// </summary>
    public byte CpuPercentAvg;

    /// <summary>
    /// Gets or sets the amount of RAM used by this lot server.
    /// </summary>
    public long RamUsed;

    /// <summary>
    /// Gets or sets the amount of available RAM for this lot server.
    /// </summary>
    public long RamAvaliable;

    /// <summary>
    /// Gets the rank of this lot server based on its current state.
    /// </summary>
    /// <remarks>
    /// The rank is calculated as the difference between the maximum lots and the total of current lots and in-flight lots.
    /// </remarks>
    public int Rank
    {
        get
        {
            // Dumb rank for now
            var lots = CurrentLots + InFlight.Count;
            return MaxLots - lots;
        }
    }
}

/// <summary>
/// Represents an attempt to pick a lot from a lot server.
/// </summary>
public class LotPickerAttempt
{
    /// <summary>
    /// Gets or sets a value indicating whether the attempt to pick a lot was successful.
    /// </summary>
    public bool Success;

    private LotServerState State;

    /// <summary>
    /// Initializes a new instance of the <see cref="LotPickerAttempt"/> class with the specified <see cref="LotServerState"/>.
    /// </summary>
    /// <param name="state">The lot server state associated with this attempt.</param>
    public LotPickerAttempt(LotServerState state)
    {
        this.State = state;
    }

    /// <summary>
    /// Frees the lot picker attempt by removing it from the list of in-flight attempts of the associated lot server state.
    /// </summary>
    public void Free()
    {
        State.InFlight.Remove(this);
    }

    /// <summary>
    /// Gets the Gluon session associated with this lot picker attempt.
    /// </summary>
    public IGluonSession Session
    {
        get { return State.Session; }
    }
}
