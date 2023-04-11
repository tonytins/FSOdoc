using FSO.Common.Utils;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Web;
using System.Xml;

using System.Net;
using System.Net.Http;
using System.Text;
using System.Xml;

namespace FSO.Server.Api.Utils
{
    /// <summary>
    /// Utility class for creating HTTP response messages.
    /// </summary>
    public class ApiResponse
    {
        /// <summary>
        /// Creates an HTTP response message with plain text content.
        /// </summary>
        /// <param name="code">The HTTP status code.</param>
        /// <param name="text">The plain text content of the response.</param>
        /// <returns>HTTP response message with plain text content.</returns>
        public static HttpResponseMessage Plain(HttpStatusCode code, string text)
        {
            var response = new HttpResponseMessage(code);
            response.Content = new StringContent(text, Encoding.UTF8, "text/plain");
            return response;
        }

        /// <summary>
        /// Creates an HTTP response message with JSON content.
        /// </summary>
        /// <param name="code">The HTTP status code.</param>
        /// <param name="obj">The object to be serialized as JSON.</param>
        /// <returns>HTTP response message with JSON content.</returns>
        public static HttpResponseMessage Json(HttpStatusCode code, object obj)
        {
            var response = new HttpResponseMessage(code);
            response.Content = new StringContent(Newtonsoft.Json.JsonConvert.SerializeObject(obj), Encoding.UTF8, "application/json");
            return response;
        }

        /// <summary>
        /// Creates an HTTP response message with XML content.
        /// </summary>
        /// <param name="code">The HTTP status code.</param>
        /// <param name="xml">The IXMLEntity object to be serialized as XML.</param>
        /// <returns>HTTP response message with XML content.</returns>
        public static HttpResponseMessage Xml(HttpStatusCode code, IXMLEntity xml)
        {
            var doc = new XmlDocument();
            var firstChild = xml.Serialize(doc);
            doc.AppendChild(firstChild);

            var response = new HttpResponseMessage(code);
            response.Content = new StringContent(doc.OuterXml, Encoding.UTF8, "text/xml");
            return response;
        }

        /// <summary>
        /// Creates a delegate that returns an HTTP response message with XML content.
        /// </summary>
        /// <param name="code">The HTTP status code.</param>
        /// <param name="xml">The IXMLEntity object to be serialized as XML.</param>
        /// <returns>Delegate that returns an HTTP response message with XML content.</returns>
        public static Func<HttpResponseMessage> XmlFuture(HttpStatusCode code, IXMLEntity xml)
        {
            var doc = new XmlDocument();
            var firstChild = xml.Serialize(doc);
            doc.AppendChild(firstChild);
            var serialized = doc.OuterXml;

            return () =>
            {
                var response = new HttpResponseMessage(code);
                response.Content = new StringContent(serialized, Encoding.UTF8, "text/xml");
                return response;
            };
        }
    }
}
