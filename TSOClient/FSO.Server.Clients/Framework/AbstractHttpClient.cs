using RestSharp;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;

namespace FSO.Server.Clients.Framework
{
    /// <summary>
    /// Represents an abstract base class for HTTP clients used in the framework.
    /// </summary>
    public abstract class AbstractHttpClient
    {
        /// <summary>
        /// Gets or sets the base URL for the HTTP client.
        /// </summary>
        public string BaseUrl { get; internal set; }

        private CookieContainer Cookies = new CookieContainer();

        /// <summary>
        /// Initializes a new instance of the AbstractHttpClient class with the specified base URL.
        /// </summary>
        /// <param name="baseUrl">The base URL for the HTTP client.</param>
        public AbstractHttpClient(string baseUrl)
        {
            this.BaseUrl = baseUrl;
        }

        /// <summary>
        /// Sets the base URL for the HTTP client.
        /// </summary>
        /// <param name="url">The base URL to set.</param>
        public void SetBaseUrl(string url)
        {
            BaseUrl = url;
        }

        /// <summary>
        /// Creates and returns a RestClient instance with the current base URL and cookie container.
        /// </summary>
        /// <returns>A RestClient instance configured with the base URL and cookie container.</returns>
        protected RestClient Client()
        {
            var client = new RestClient(BaseUrl);
            client.CookieContainer = Cookies;
            return client;
        }
    }

}
