/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
 * If a copy of the MPL was not distributed with this file, You can obtain one at
 * http://mozilla.org/MPL/2.0/. 
 */

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;

namespace FSO.SimAntics.NetPlay.Model
{
    /// <summary>
    /// Represents a list of <see cref="VMNetTick"/> objects that can be serialized for network communication.
    /// </summary>
    public class VMNetTickList : VMSerializable
    {
        /// <summary>
        /// Gets or sets a value indicating whether the immediate mode is enabled.
        /// </summary>
        public bool ImmediateMode = false;

        /// <summary>
        /// Gets or sets the list of <see cref="VMNetTick"/> objects.
        /// </summary>
        public List<VMNetTick> Ticks;

        #region VMSerializable Members

        /// <summary>
        /// Serializes the object into a <see cref="BinaryWriter"/> for network communication.
        /// </summary>
        /// <param name="writer">The <see cref="BinaryWriter"/> to write the serialized data to.</param>
        public void SerializeInto(BinaryWriter writer)
        {
            writer.Write(ImmediateMode);
            if (Ticks == null)
                writer.Write(0);
            else
            {
                writer.Write(Ticks.Count);
                for (int i = 0; i < Ticks.Count; i++)
                {
                    Ticks[i].SerializeInto(writer);
                }
            }
        }

        /// <summary>
        /// Deserializes the object from a <see cref="BinaryReader"/> after network communication.
        /// </summary>
        /// <param name="reader">The <see cref="BinaryReader"/> to read the serialized data from.</param>
        public void Deserialize(BinaryReader reader)
        {
            ImmediateMode = reader.ReadBoolean();
            Ticks = new List<VMNetTick>();
            int length = reader.ReadInt32();
            for (int i = 0; i < length; i++)
            {
                var cmds = new VMNetTick();
                cmds.Deserialize(reader);
                Ticks.Add(cmds);
            }
        }

        #endregion
    }
}

