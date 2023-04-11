using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading.Tasks;

namespace FSO.Server.Common
{
    /// <summary>
    /// Utility class for creating an instance of <see cref="System.Net.IPEndPoint"/>.
    /// </summary>
    public class IPEndPointUtils
    {
        /// <summary>
        /// Creates an instance of <see cref="System.Net.IPEndPoint"/> from the provided endpoint string.
        /// </summary>
        /// <param name="endPoint">The endpoint string in the format "ip:port".</param>
        /// <returns>An instance of <see cref="System.Net.IPEndPoint"/>.</returns>
        /// <exception cref="System.FormatException">Thrown when the endpoint string is in an invalid format.</exception>
        public static System.Net.IPEndPoint CreateIPEndPoint(string endPoint)
        {
            string[] ep = endPoint.Split(':');
            if (ep.Length != 2) throw new System.FormatException("Invalid endpoint format");

            System.Net.IPAddress ip;
            if (!System.Net.IPAddress.TryParse(ep[0], out ip))
            {
                var addrs = System.Net.Dns.GetHostEntry(ep[0]).AddressList;
                if (addrs.Length == 0)
                {
                    throw new System.FormatException("Invalid IP address");
                }
                else ip = addrs[0];
            }

            int port;
            if (!int.TryParse(ep[1], System.Globalization.NumberStyles.None, System.Globalization.NumberFormatInfo.CurrentInfo, out port))
            {
                throw new System.FormatException("Invalid port");
            }

            return new System.Net.IPEndPoint(ip, port);
        }
    }
}
