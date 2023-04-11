using FSO.Common.Utils;
using FSO.Server.Clients.Framework;
using FSO.Server.Protocol.CitySelector;
using RestSharp;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FSO.Server.Clients
{
    /// <summary>
    /// Represents a client for interacting with the city server.
    /// </summary>
    public class CityClient : AbstractHttpClient
    {
        /// <summary>
        /// Initializes a new instance of the CityClient class with the specified base URL.
        /// </summary>
        /// <param name="baseUrl">The base URL of the city server.</param>
        public CityClient(string baseUrl) : base(baseUrl)
        {
        }

        /// <summary>
        /// Sends a request to the ShardSelectorServlet on the city server.
        /// </summary>
        /// <param name="input">The input parameters for the ShardSelectorServlet.</param>
        /// <returns>The response from the ShardSelectorServlet.</returns>
        public ShardSelectorServletResponse ShardSelectorServlet(ShardSelectorServletRequest input)
        {
            var client = Client();

            // Build the request with query parameters
            var request = new RestRequest("cityselector/app/ShardSelectorServlet")
                            .AddQueryParameter("shardName", input.ShardName)
                            .AddQueryParameter("avatarId", input.AvatarID);

            var response = client.Execute(request);

            // Check for response status code and throw exception if not OK
            if (response.StatusCode != System.Net.HttpStatusCode.OK)
            {
                throw new Exception("Unknown error during ShardSelectorServlet");
            }

            // Parse the XML response content into a strongly typed object and return it
            return XMLUtils.Parse<ShardSelectorServletResponse>(response.Content);
        }

        /// <summary>
        /// Sends a request to the InitialConnectServlet on the city server.
        /// </summary>
        /// <param name="input">The input parameters for the InitialConnectServlet.</param>
        /// <returns>The response from the InitialConnectServlet.</returns>
        public InitialConnectServletResult InitialConnectServlet(InitialConnectServletRequest input)
        {
            var client = Client();

            // Build the request with query parameters
            var request = new RestRequest("cityselector/app/InitialConnectServlet")
                            .AddQueryParameter("ticket", input.Ticket)
                            .AddQueryParameter("version", input.Version);

            var response = client.Execute(request);

            // Check for response status code and throw exception if not OK
            if (response.StatusCode != System.Net.HttpStatusCode.OK)
            {
                throw new Exception("Unknown error during InitialConnectServlet");
            }

            // Parse the XML response content into a strongly typed object and return it
            return XMLUtils.Parse<InitialConnectServletResult>(response.Content);
        }

        /// <summary>
        /// Sends a request to the AvatarDataServlet on the city server.
        /// </summary>
        /// <returns>The list of AvatarData returned by the AvatarDataServlet.</returns>
        public List<AvatarData> AvatarDataServlet()
        {
            var client = Client();

            var request = new RestRequest("cityselector/app/AvatarDataServlet");

            // Check for response status code and throw exception if not OK
            if (response.StatusCode != System.Net.HttpStatusCode.OK)
            {
                throw new Exception("Unknown error during AvatarDataServlet");
            }

            // Parse the XML response content into a strongly typed list of objects and return it
            List<AvatarData> result = (List<AvatarData>)XMLUtils.Parse<XMLList<AvatarData>>(response.Content);
            return result;
        }


        /// <summary>
        /// Retrieves the list of shard status items from the server.
        /// </summary>
        /// <returns>A list of <see cref="ShardStatusItem"/> objects representing the status of shards.</returns>
        /// <exception cref="Exception">Thrown if an unknown error occurs during the ShardStatus request.</exception>
        public List<ShardStatusItem> ShardStatus()
        {
            var client = Client();

            var request = new RestRequest("cityselector/shard-status.jsp");

            var response = client.Execute(request);
            if (response.StatusCode != System.Net.HttpStatusCode.OK)
            {
                throw new Exception("Unknown error during ShardStatus");
            }

            List<ShardStatusItem> result = (List<ShardStatusItem>)XMLUtils.Parse<XMLList<ShardStatusItem>>(response.Content);
            return result;
        }

    }
}
