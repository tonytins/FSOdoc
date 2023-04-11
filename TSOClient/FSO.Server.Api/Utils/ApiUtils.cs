using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Web;
using System.Web.Http;

namespace FSO.Server.Api.Utils
{
    /// <summary>
    /// Utility class for common API functions.
    /// </summary>
    public class ApiUtils
    {
        /// <summary>
        /// Retrieves the IP address from the X-Forwarded-For header in the HttpRequestMessage.
        /// </summary>
        /// <param name="request">The HttpRequestMessage object.</param>
        /// <returns>The IP address extracted from the X-Forwarded-For header. Returns "127.0.0.1" if header not present.</returns>
        public static string GetIP(HttpRequestMessage request)
        {
            var ip = "127.0.0.1";
            if (request.Headers.Contains("X-Forwarded-For"))
            {
                ip = request.Headers.GetValues("X-Forwarded-For").First();
                ip = ip.Substring(ip.IndexOf(",") + 1);
                var last = ip.LastIndexOf(":");
                if (last < ip.Length - 5) ip = ip.Substring(0, last);
            }
            return ip;
        }
    }
}