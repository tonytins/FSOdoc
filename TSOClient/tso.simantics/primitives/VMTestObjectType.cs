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
using FSO.SimAntics.Engine.Scopes;
using FSO.Files.Utils;
using FSO.SimAntics.Engine.Utils;
using System.IO;

namespace FSO.SimAntics.Primitives
{
    /// <summary>
    /// Represents a primitive handler for testing object type in a virtual machine.
    /// </summary>
    public class VMTestObjectType : VMPrimitiveHandler
    {
        /// <summary>
        /// Executes the VM primitive to test if the object type matches the provided GUID.
        /// </summary>
        /// <param name="context">The VM stack frame context.</param>
        /// <param name="args">The operand containing the required data for the operation.</param>
        /// <returns>The exit code indicating the result of the operation.</returns>
        public override VMPrimitiveExitCode Execute(VMStackFrame context, VMPrimitiveOperand args)
        {
            var operand = (VMTestObjectTypeOperand)args;
            var objectID = VMMemory.GetVariable(context, operand.IdOwner, operand.IdData);

            var obj = context.VM.GetObjectById(objectID);
            //var obj = context.StackObject;
            if (obj == null)
            {
                return VMPrimitiveExitCode.ERROR;
            }

            if (obj.Object.GUID == operand.GUID)
            {
                return VMPrimitiveExitCode.GOTO_TRUE; // is my guid same?
            }
            else if (obj.MasterDefinition != null && (obj.MasterDefinition.GUID == operand.GUID))
            {
                return VMPrimitiveExitCode.GOTO_TRUE; // is master guid same?
            }
            else
            {
                return VMPrimitiveExitCode.GOTO_FALSE;
            }
        }
    }

    /// <summary>
    /// Represents an operand for the VMTestObjectType primitive, containing data for the object type test.
    /// </summary>
    public class VMTestObjectTypeOperand : VMPrimitiveOperand
    {
        /// <summary>
        /// Gets or sets the GUID of the object type to test against.
        /// </summary>
        public uint GUID { get; set; }

        /// <summary>
        /// Gets or sets the data ID of the object to test.
        /// </summary>
        public short IdData { get; set; }

        /// <summary>
        /// Gets or sets the owner scope of the object to test.
        /// </summary>
        public VMVariableScope IdOwner { get; set; }

        #region VMPrimitiveOperand Members
        /// <summary>
        /// Reads the operand data from a byte array and sets the corresponding properties.
        /// </summary>
        /// <param name="bytes">The byte array containing the operand data.</param>
        public void Read(byte[] bytes)
        {
            using (var io = IoBuffer.FromBytes(bytes, ByteOrder.LITTLE_ENDIAN))
            {
                GUID = io.ReadUInt32();
                IdData = io.ReadInt16();
                IdOwner = (VMVariableScope)io.ReadByte();
            }
        }

        /// <summary>
        /// Writes the operand data to a byte array based on the current property values.
        /// </summary>
        /// <param name="bytes">The byte array to write the operand data to.</param>
        public void Write(byte[] bytes)
        {
            using (var io = new BinaryWriter(new MemoryStream(bytes)))
            {
                io.Write(GUID);
                io.Write(IdData);
                io.Write((byte)IdOwner);
            }
        }
        #endregion
    }
}
