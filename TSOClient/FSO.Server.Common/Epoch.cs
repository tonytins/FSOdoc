using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FSO.Server.Common
{
    /// <summary>
    /// Utility class for working with Epoch time (Unix timestamp).
    /// </summary>
    public class Epoch
    {
        /// <summary>
        /// Gets the current Epoch time (Unix timestamp) in seconds.
        /// </summary>
        public static uint Now
        {
            get
            {
                // Calculate the current Epoch time (Unix timestamp) by subtracting the Unix Epoch time (1970-01-01) from the current UTC time.
                uint epoch = (uint)(DateTime.UtcNow - new DateTime(1970, 1, 1)).TotalSeconds;
                return epoch;
            }
        }

        /// <summary>
        /// Converts a DateTime object to Epoch time (Unix timestamp) in seconds.
        /// </summary>
        /// <param name="time">The DateTime object to convert.</param>
        /// <returns>The Epoch time (Unix timestamp) in seconds.</returns>
        public static uint FromDate(DateTime time)
        {
            // Calculate the Epoch time (Unix timestamp) of the provided DateTime object by subtracting the Unix Epoch time (1970-01-01) from the UTC time of the provided DateTime object.
            return (uint)(time.ToUniversalTime() - new DateTime(1970, 1, 1)).TotalSeconds;
        }

        /// <summary>
        /// Converts an Epoch time (Unix timestamp) in seconds to a DateTime object.
        /// </summary>
        /// <param name="time">The Epoch time (Unix timestamp) in seconds.</param>
        /// <returns>The DateTime object representing the converted Epoch time.</returns>
        public static DateTime ToDate(uint time)
        {
            // Create a DateTime object representing the Unix Epoch time (1970-01-01) in UTC, and add the seconds from the provided Epoch time to get the corresponding DateTime object.
            var epoch = new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc);
            return epoch.AddSeconds(time);
        }

        /// <summary>
        /// Gets the default Epoch time (Unix timestamp) value, which is 0.
        /// </summary>
        public static uint Default
        {
            get { return 0; }
        }
    }
}