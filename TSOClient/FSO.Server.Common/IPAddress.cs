using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading.Tasks;

namespace FSO.Server.Common
{
    /// <summary>
    /// Utility class for getting IP address from HttpListenerRequest or IPEndPoint.
    /// </summary>
    public class IPAddress
    {
        /// <summary>
        /// Gets the IP address from the provided HttpListenerRequest.
        /// </summary>
        /// <param name="httpRequest">The HttpListenerRequest object.</param>
        /// <returns>The IP address as a string.</returns>
        public static string Get(HttpListenerRequest httpRequest)
        {
            if (httpRequest.Headers["X-Forwarded-For"] != null)
            {
                // If X-Forwarded-For header is present, use its value as IP address.
                return httpRequest.Headers["X-Forwarded-For"];
            }

            // If X-Forwarded-For header is not present, use RemoteEndPoint as IP address.
            return Get(httpRequest.RemoteEndPoint);
        }

        /// <summary>
        /// Gets the IP address from the provided IPEndPoint.
        /// </summary>
        /// <param name="endpoint">The IPEndPoint object.</param>
        /// <returns>The IP address as a string.</returns>
        public static string Get(IPEndPoint endpoint)
        {
            // Return the IP address as string from the provided IPEndPoint.
            return endpoint.Address.ToString();
        }
    }
}