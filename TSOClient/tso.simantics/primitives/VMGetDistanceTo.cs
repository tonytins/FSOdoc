/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
 * If a copy of the MPL was not distributed with this file, You can obtain one at
 * http://mozilla.org/MPL/2.0/. 
 */

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using FSO.SimAntics.Engine;
using FSO.Files.Utils;
using FSO.SimAntics.Engine.Utils;
using FSO.SimAntics.Engine.Scopes;
using System.IO;

namespace FSO.SimAntics.Primitives
{
    public class VMGetDistanceTo : VMPrimitiveHandler
    {
        /// <summary>
        /// Executes the GetDistanceTo primitive operation.
        /// </summary>
        /// <param name="context">The VMStackFrame context.</param>
        /// <param name="args">The VMPrimitiveOperand arguments.</param>
        /// <returns>The VMPrimitiveExitCode after execution.</returns>
        public override VMPrimitiveExitCode Execute(VMStackFrame context, VMPrimitiveOperand args)
        {
            // Cast the argument to VMGetDistanceToOperand
            var operand = (VMGetDistanceToOperand)args;

            // Get the first object from the stack
            var obj1 = context.StackObject;
            VMEntity obj2;
            if ((operand.Flags & 1) == 0)
                // If the flag is not set, use the Caller as the second object
                obj2 = context.Caller;
            else
                // Otherwise, get the object by ID from the VM memory using the operand's data
                obj2 = context.VM.GetObjectById(VMMemory.GetVariable(context, (VMVariableScope)operand.ObjectScope, operand.OScopeData));

            // Get the positions of the two objects
            var pos1 = obj1.Position;
            var pos2 = obj2.Position;

            // Calculate the distance between the two objects using the distance formula
            var result = (short)Math.Floor(Math.Sqrt(Math.Pow(pos1.x - pos2.x, 2) + Math.Pow(pos1.y - pos2.y, 2)) / 16.0);

            // Store the result in the temporary register specified by the operand
            context.Thread.TempRegisters[operand.TempNum] = result;

            // Return the exit code indicating success
            return VMPrimitiveExitCode.GOTO_TRUE;
        }
    }

    public class VMGetDistanceToOperand : VMPrimitiveOperand
    {
        /// <summary>
        /// Gets or sets the temporary register number.
        /// </summary>
        public ushort TempNum { get; set; }

        /// <summary>
        /// Gets or sets the flags.
        /// </summary>
        public byte Flags { get; set; }

        /// <summary>
        /// Gets or sets the object scope.
        /// </summary>
        public VMVariableScope ObjectScope { get; set; }

        /// <summary>
        /// Gets or sets the object scope data.
        /// </summary>
        public short OScopeData { get; set; }

        #region VMPrimitiveOperand Members

        /// <summary>
        /// Reads the operand data from a byte array.
        /// </summary>
        /// <param name="bytes">The byte array to read from.</param>
        public void Read(byte[] bytes)
        {
            using (var io = IoBuffer.FromBytes(bytes, ByteOrder.LITTLE_ENDIAN))
            {
                // Read the operand data from the byte array using Little Endian byte order
                TempNum = io.ReadUInt16();
                Flags = io.ReadByte();
                ObjectScope = (VMVariableScope)io.ReadByte();
                OScopeData = io.ReadInt16();

                // If the Flags indicate that the object scope is not set, set it to MyObject with OScopeData value of 11
                if ((Flags & 1) == 0)
                {
                    ObjectScope = VMVariableScope.MyObject;
                    OScopeData = 11;
                }

                // Set the flag to indicate that the object scope is set
                Flags |= 1;
            }
        }

        /// <summary>
        /// Writes the operand data to a byte array.
        /// </summary>
        /// <param name="bytes">The byte array to write to.</param>
        public void Write(byte[] bytes)
        {
            using (var io = new BinaryWriter(new MemoryStream(bytes)))
            {
                // Write the operand data to the byte array
                io.Write(TempNum);
                io.Write(Flags);
                io.Write((byte)ObjectScope);
                io.Write(OScopeData);
            }
        }

        #endregion
    }
}
