using FSO.Common.Security;
using FSO.Common.Serialization.Primitives;
using FSO.Files.Formats.tsodata;
using FSO.Server.DataService.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FSO.Common.DataService
{
    /// <summary>
    /// Represents the interface for a data service that provides methods for retrieving, invalidating, and updating data.
    /// </summary>
    public interface IDataService
    {
        /// <summary>
        /// Asynchronously retrieves an object of the specified type with the given key from the data service.
        /// </summary>
        /// <typeparam name="T">The type of object to retrieve.</typeparam>
        /// <param name="key">The key used to identify the object.</param>
        /// <returns>A task that represents the asynchronous operation and contains the retrieved object.</returns>
        Task<T> Get<T>(object key);

        /// <summary>
        /// Asynchronously retrieves an array of objects of the specified type with the given keys from the data service.
        /// </summary>
        /// <typeparam name="T">The type of objects to retrieve.</typeparam>
        /// <param name="keys">The keys used to identify the objects.</param>
        /// <returns>A task that represents the asynchronous operation and contains an array of retrieved objects.</returns>
        Task<T[]> GetMany<T>(object[] keys);

        /// <summary>
        /// Asynchronously retrieves an object of the specified type with the given key from the data service.
        /// </summary>
        /// <param name="type">The type of object to retrieve.</param>
        /// <param name="key">The key used to identify the object.</param>
        /// <returns>A task that represents the asynchronous operation and contains the retrieved object.</returns>
        Task<object> Get(Type type, object key);

        /// <summary>
        /// Asynchronously retrieves an object of the specified type with the given key from the data service.
        /// </summary>
        /// <param name="type">The type of object to retrieve.</param>
        /// <param name="key">The key used to identify the object.</param>
        /// <returns>A task that represents the asynchronous operation and contains the retrieved object.</returns>
        Task<object> Get(uint type, object key);

        /// <summary>
        /// Asynchronously retrieves an object of the specified type with the given key from the data service.
        /// </summary>
        /// <param name="type">The type of object to retrieve.</param>
        /// <param name="key">The key used to identify the object.</param>
        /// <returns>A task that represents the asynchronous operation and contains the retrieved object.</returns>
        Task<object> Get(MaskedStruct type, object key);

        /// <summary>
        /// Invalidates the object with the specified key in the data service for the given type.
        /// </summary>
        /// <typeparam name="T">The type of object to invalidate.</typeparam>
        /// <param name="key">The key used to identify the object to invalidate.</param>
        void Invalidate<T>(object key);

        /// <summary>
        /// Invalidates the object with the specified key in the data service for the given type and replaces it with the specified replacement object.
        /// </summary>
        /// <typeparam name="T">The type of object to invalidate and replace.</typeparam>
        /// <param name="key">The key used to identify the object to invalidate.</param>
        /// <param name="replacement">The replacement object to store in the data service.</param>
        void Invalidate<T>(object key, T replacement);

        /// <summary>
        /// Serializes an update message for the specified masked struct, object value, and ID.
        /// </summary>
        /// <param name="mask">The masked struct to update.</param>
        /// <param name="value">The object value to serialize.</param>
        /// <param name="id">The ID of the update message.</param>
        /// <returns>A list of serialized update messages.</returns>
        List<cTSOTopicUpdateMessage> SerializeUpdate(MaskedStruct mask, object value, uint id);

        /// <summary>
        /// Serializes an update message for the specified struct fields, object value, and ID.
        /// </summary>
        /// <param name="fields">The struct fields to update.</param>
        /// <param name="value">The object value to serialize.</param>
        /// <param name="id">The ID of the update message.</param>
        /// <returns>A list of serialized update messages.</returns>
        List<cTSOTopicUpdateMessage> SerializeUpdate(StructField[] fields, object value, uint id);

        /// <summary>
        /// Asynchronously serializes a path for the specified dot path.
        /// </summary>
        /// <param name="dotPath">The dot path to serialize.</param>
        /// <returns>A task that represents the asynchronous operation and contains the serialized update message.</returns>
        Task<cTSOTopicUpdateMessage> SerializePath(params uint[] dotPath);

        /// <summary>
        /// Applies an update message to the data service with the specified security context.
        /// </summary>
        /// <param name="update">The update message to apply.</param>
        /// <param name="context">The security context to use for applying the update.</param>
        void ApplyUpdate(cTSOTopicUpdateMessage update, ISecurityContext context);

        /// <summary>
        /// Gets the struct fields with the specified field names for the specified type.
        /// </summary>
        /// <param name="type">The type of the object to get fields for.</param>
        /// <param name="fieldNames">The names of the fields to get.</param>
        /// <returns>An array of struct fields.</returns>
        StructField[] GetFieldsByName(Type type, params string[] fieldNames);

    }
}
