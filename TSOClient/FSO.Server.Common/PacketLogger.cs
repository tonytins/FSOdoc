using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FSO.Server.Common
{
    /// <summary>
    /// Represents an interface for logging network packets.
    /// </summary>
    public interface IPacketLogger
    {
        /// <summary>
        /// Logs a network packet.
        /// </summary>
        /// <param name="packet">The packet to be logged.</param>
        void OnPacket(Packet packet);
    }

    /// <summary>
    /// Represents a network packet.
    /// </summary>
    public class Packet
    {
        /// <summary>
        /// Gets or sets the type of the packet.
        /// </summary>
        public PacketType Type { get; set; }

        /// <summary>
        /// Gets or sets the subtype of the packet.
        /// </summary>
        public uint SubType { get; set; }

        /// <summary>
        /// Gets or sets the data of the packet.
        /// </summary>
        public byte[] Data { get; set; }

        /// <summary>
        /// Gets or sets the direction of the packet.
        /// </summary>
        public PacketDirection Direction { get; set; }
    }

    /// <summary>
    /// Represents the type of a network packet.
    /// </summary>
    public enum PacketType
    {
        ARIES,
        VOLTRON,
        ELECTRON
    }

    /// <summary>
    /// Represents the direction of a network packet.
    /// </summary>
    public enum PacketDirection
    {
        OUTPUT,
        INPUT
    }
}
