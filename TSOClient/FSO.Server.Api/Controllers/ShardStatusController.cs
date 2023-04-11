using FSO.Common.Utils;
using FSO.Server.Api.Utils;
using FSO.Server.Protocol.CitySelector;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;

namespace FSO.Server.Api.Controllers
{
    public class ShardStatusController : ApiController
    {
        /// <summary>
        /// Retrieves the shard status information.
        /// </summary>
        /// <returns>HTTP response message containing the shard status information in XML format.</returns>
        public HttpResponseMessage Get()
        {
            var api = Api.INSTANCE;

            var result = new XMLList<ShardStatusItem>("Shard-Status-List");
            var shards = api.Shards.All;
            foreach (var shard in shards)
            {
                result.Add(shard);
            }

            // Return HTTP response message with OK status code and shard status information in XML format
            return ApiResponse.Xml(HttpStatusCode.OK, result);
        }
    }
}