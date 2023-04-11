using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Web.Http;

namespace FSO.Server.Api.Controllers
{
    public class LotThumbController : ApiController
    {
        /// <summary>
        /// Retrieves the lot thumbnail image for a given shard ID and lot ID.
        /// </summary>
        /// <param name="shardid">The ID of the shard.</param>
        /// <param name="id">The ID of the lot.</param>
        /// <returns>An HttpResponseMessage containing the lot thumbnail image.</returns>
        public HttpResponseMessage Get(int shardid, uint id)
        {
            var api = Api.INSTANCE;

            using (var da = api.DAFactory.Get())
            {
                var lot = da.Lots.GetByLocation(shardid, id);

                if (lot == null)
                {
                    // If lot is not found, return 404 (Not Found) response
                    return new HttpResponseMessage(HttpStatusCode.NotFound);
                }

                FileStream stream;
                try
                {
                    // Read the thumbnail image file from disk
                    stream = File.OpenRead(Path.Combine(api.Config.NFSdir, "Lots/" + lot.lot_id.ToString("x8") + "/thumb.png"));

                    // Create an HTTP response with OK status code
                    HttpResponseMessage response = new HttpResponseMessage(HttpStatusCode.OK);

                    // Set the response content to the thumbnail image
                    response.Content = new StreamContent(stream);

                    // Set cache control headers to allow public caching for 3 minutes
                    response.Headers.CacheControl = new CacheControlHeaderValue()
                    {
                        Public = true,
                        MaxAge = new TimeSpan(0, 3, 0),
                    };

                    // Set the content type header to indicate it's a PNG image
                    response.Content.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue("image/png");

                    return response;
                }
                catch (Exception e)
                {
                    // If an exception occurs while reading the image file, return 404 (Not Found) response
                    return new HttpResponseMessage(HttpStatusCode.NotFound);
                }
            }
        }
    }
}
