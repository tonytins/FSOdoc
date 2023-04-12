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
using FSO.SimAntics.Engine.Scopes;
using System.IO;

namespace FSO.SimAntics.Primitives
{
    /// <summary>
    /// Generally something bad has happened when this is called.
    /// </summary>
    public class VMBreakPoint : VMPrimitiveHandler
    {
        /// <summary>
        /// Executes the VMPrimitiveHandler logic for a breakpoint.
        /// </summary>
        /// <param name="context">The VMStackFrame context.</param>
        /// <param name="args">The VMPrimitiveOperand arguments.</param>
        /// <returns>The exit code for the VMPrimitiveHandler.</returns>
        public override VMPrimitiveExitCode Execute(VMStackFrame context, VMPrimitiveOperand args)
        {
            //todo: check condition
            return VMPrimitiveExitCode.GOTO_TRUE;
        }
    }

    public class VMBreakPointOperand : VMPrimitiveOperand
    {
        /// <summary>
        /// Gets or sets the data value of the VMBreakPointOperand.
        /// </summary>
        public short Data { get; set; }
        /// <summary>
        /// Gets or sets the variable scope of the VMBreakPointOperand.
        /// </summary>
        public VMVariableScope Scope { get; set; }

        #region VMPrimitiveOperand Members

        /// <summary>
        /// Reads the byte array and sets the Data and Scope properties accordingly.
        /// </summary>
        /// <param name="bytes">The byte array to read.</param>
        public void Read(byte[] bytes)
        {
            using (var io = IoBuffer.FromBytes(bytes, ByteOrder.LITTLE_ENDIAN))
            {
                Data = io.ReadInt16();
                Scope = (VMVariableScope)io.ReadUInt16();
            }
        }

        /// <summary>
        /// Writes the Data and Scope properties to a byte array.
        /// </summary>
        /// <param name="bytes">The byte array to write.</param>
        public void Write(byte[] bytes)
        {
            using (var io = new BinaryWriter(new MemoryStream(bytes)))
            {
                io.Write(Data);
                io.Write((ushort)Scope);
            }
        }
        #endregion
    }
}
