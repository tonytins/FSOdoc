using Nancy;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Nancy.Security;
using FSO.Server.Database.DA.Utils;
using FSO.Common.Utils;
using System.Xml;
using FSO.Server.Servers.Api.JsonWebToken;

namespace FSO.Server.Servers.Api
{
    /// <summary>
    /// Extension methods for NancyModule class.
    /// </summary>
    public static class NancyExtensions
    {
        /// <summary>
        /// Requires the user to be authenticated as a moderator.
        /// </summary>
        /// <param name="controller">The NancyModule instance.</param>
        public static void DemandModerator(this NancyModule controller)
        {
            controller.RequiresAuthentication(); // Require authentication
            var user = (JWTUserIdentity)controller.Context.CurrentUser; // Get the current user from the context
            user.Claims.Contains("moderator"); // Check if user has "moderator" claim
        }

        /// <summary>
        /// Requires the user to be authenticated as an admin.
        /// </summary>
        /// <param name="controller">The NancyModule instance.</param>
        public static void DemandAdmin(this NancyModule controller)
        {
            controller.RequiresAuthentication(); // Require authentication
            var user = (JWTUserIdentity)controller.Context.CurrentUser; // Get the current user from the context
            user.Claims.Contains("admin"); // Check if user has "admin" claim
        }

        /// <summary>
        /// Formats the given list as JSON response with pagination headers.
        /// </summary>
        /// <typeparam name="T">The type of the list items.</typeparam>
        /// <param name="formatter">The IResponseFormatter instance.</param>
        /// <param name="list">The PagedList instance to format.</param>
        /// <returns>The JSON response with pagination headers.</returns>
        public static Response AsPagedList<T>(this IResponseFormatter formatter, PagedList<T> list)
        {
            return FormatterExtensions.AsJson<PagedList<T>>(formatter, list) // Format list as JSON
                        .WithHeader("X-Total-Count", list.Total.ToString()) // Add "X-Total-Count" header
                        .WithHeader("X-Offset", list.Offset.ToString()); // Add "X-Offset" header
        }

        /// <summary>
        /// Formats the given entity as XML response with text/xml content type.
        /// </summary>
        /// <param name="formatter">The IResponseFormatter instance.</param>
        /// <param name="entity">The IXMLEntity instance to format.</param>
        /// <returns>The XML response with text/xml content type.</returns>
        public static Response AsXml(this IResponseFormatter formatter, IXMLEntity entity)
        {
            var doc = new XmlDocument(); // Create a new XML document
            var firstChild = entity.Serialize(doc); // Serialize the entity to XML
            doc.AppendChild(firstChild); // Append the serialized entity as the first child

            return FormatterExtensions.AsText(formatter, doc.OuterXml).WithContentType("text/xml"); // Format the XML as text with content type "text/xml"
        }
    }
}