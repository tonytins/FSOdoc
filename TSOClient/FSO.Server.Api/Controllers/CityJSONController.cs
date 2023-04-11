using FSO.Server.Api.Utils;
using FSO.Server.Common;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;

namespace FSO.Server.Api.Controllers
{
    public class CityJSONController : ApiController
    {
        private static object ModelLock = new object { };
        private static CityInfoModel LastModel = new CityInfoModel();
        private static uint LastModelUpdate;

        /// <summary>
        /// Retrieves CityInfoModel data for a specific shard ID.
        /// </summary>
        /// <param name="shardid">The ID of the shard for which to retrieve data.</param>
        /// <returns>An HttpResponseMessage containing the CityInfoModel data as JSON.</returns>
        public HttpResponseMessage Get(int shardid)
        {
            var api = Api.INSTANCE;

            var now = Epoch.Now;

            // Check if LastModel data needs to be updated
            if (LastModelUpdate < now - 15)
            {
                LastModelUpdate = now;
                lock (ModelLock)
                {
                    LastModel = new CityInfoModel();
                    using (var da = api.DAFactory.Get())
                    {
                        var lots = da.Lots.AllLocations(shardid);
                        var lotstatus = da.LotClaims.AllLocations(shardid);
                        LastModel.reservedLots = lots.ConvertAll(x => x.location).ToArray();
                        LastModel.names = lots.ConvertAll(x => x.name).ToArray();
                        LastModel.activeLots = lotstatus.ConvertAll(x => x.location).ToArray();
                        LastModel.onlineCount = lotstatus.ConvertAll(x => x.active).ToArray();
                    }
                }
            }

            // Return LastModel data as JSON
            lock (ModelLock)
            {
                return ApiResponse.Json(HttpStatusCode.OK, LastModel);
            }
        }
    }

    /// <summary>
    /// Represents the data model for City information.
    /// </summary>
    class CityInfoModel
    {
        /// <summary>
        /// Array of names associated with the CityInfoModel data.
        /// </summary>
        public string[] names;

        /// <summary>
        /// Array of reserved lots associated with the CityInfoModel data.
        /// </summary>
        public uint[] reservedLots;

        /// <summary>
        /// Array of active lots associated with the CityInfoModel data.
        /// </summary>
        public uint[] activeLots;

        /// <summary>
        /// Array of online count associated with the CityInfoModel data.
        /// </summary>
        public int[] onlineCount;
    }
}
