using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FSO.Server.Common
{
    /// <summary>
    /// Represents an interface for a server debugger.
    /// </summary>
    public interface IServerDebugger
    {
        /// <summary>
        /// Gets an instance of the packet logger.
        /// </summary>
        /// <returns>An instance of the packet logger.</returns>
        IPacketLogger GetPacketLogger();

        /// <summary>
        /// Adds a socket server to the debugger.
        /// </summary>
        /// <param name="server">The socket server to be added.</param>
        void AddSocketServer(ISocketServer server);
    }

    /// <summary>
    /// Represents an interface for a socket server.
    /// </summary>
    public interface ISocketServer
    {
        /// <summary>
        /// Gets a list of socket sessions associated with the server.
        /// </summary>
        /// <returns>A list of socket sessions.</returns>
        List<ISocketSession> GetSocketSessions();
    }

    /// <summary>
    /// Represents an interface for a socket session.
    /// </summary>
    public interface ISocketSession
    {
        /// <summary>
        /// Writes data to the socket session.
        /// </summary>
        /// <param name="data">The data to be written.</param>
        void Write(params object[] data);
    }
}

