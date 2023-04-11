/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
 * If a copy of the MPL was not distributed with this file, You can obtain one at
 * http://mozilla.org/MPL/2.0/. 
 */

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;

namespace FSO.SimAntics.NetPlay.Model
{
    public interface VMSerializable
    {
        /// <summary>
        /// Serializes the object into a BinaryWriter.
        /// </summary>
        /// <param name="writer">The BinaryWriter to write the serialized data to.</param>
        void SerializeInto(BinaryWriter writer);

        /// <summary>
        /// Deserializes the object from a BinaryReader.
        /// </summary>
        /// <param name="reader">The BinaryReader to read the serialized data from.</param>
        void Deserialize(BinaryReader reader);
    }

    public static class VMSerializableUtils
    {
        /// <summary>
        /// Converts an array of objects to a byte array.
        /// </summary>
        /// <typeparam name="T">The type of objects in the array.</typeparam>
        /// <param name="input">The array of objects to convert.</param>
        /// <returns>A byte array containing the serialized data of the input array.</returns>
        public static byte[] ToByteArray<T>(T[] input)
        {
            var result = new byte[input.Length * Marshal.SizeOf(typeof(T))];
            Buffer.BlockCopy(input, 0, result, 0, result.Length);
            return result;
        }

        /// <summary>
        /// Converts a byte array to an array of objects.
        /// </summary>
        /// <typeparam name="T">The type of objects in the resulting array.</typeparam>
        /// <param name="input">The byte array to convert.</param>
        /// <returns>An array of objects deserialized from the input byte array.</returns>
        public static T[] ToTArray<T>(byte[] input)
        {
            var result = new T[input.Length / Marshal.SizeOf(typeof(T))];
            Buffer.BlockCopy(input, 0, result, 0, input.Length);
            return result;
        }
    }
}
