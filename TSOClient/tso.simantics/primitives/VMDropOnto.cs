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
using System.IO;

namespace FSO.SimAntics.Primitives
{
    public class VMDropOnto : VMPrimitiveHandler
    {
        /// <summary>
        /// Executes the drop onto operation in the virtual machine.
        /// </summary>
        /// <param name="context">The stack frame context of the current execution.</param>
        /// <param name="args">The operand containing source and destination slot information.</param>
        /// <returns>The exit code indicating the result of the operation.</returns>
        public override VMPrimitiveExitCode Execute(VMStackFrame context, VMPrimitiveOperand args)
        {
            var operand = (VMDropOntoOperand)args;
            var src = (operand.SrcSlotMode == 1) ? (ushort)context.Args[operand.SrcSlotNum] : operand.SrcSlotNum;
            var dest = (operand.DestSlotMode == 1) ? (ushort)context.Args[operand.DestSlotNum] : operand.DestSlotNum;

            var item = context.Caller.GetSlot(src);

            if (item != null)
            {
                var itemTest = context.StackObject.GetSlot(dest);

                if (itemTest == null)
                {
                    // Place the item in the destination slot and return GOTO_TRUE exit code.
                    return (context.StackObject.PlaceInSlot(item, dest, true, context.VM.Context)) ? VMPrimitiveExitCode.GOTO_TRUE : VMPrimitiveExitCode.GOTO_FALSE;
                }
                else
                {
                    // Cannot replace items currently in slots, return GOTO_FALSE exit code.
                    return VMPrimitiveExitCode.GOTO_FALSE;
                }
            }
            else
            {
                // Source item not found, return GOTO_FALSE exit code.
                return VMPrimitiveExitCode.GOTO_FALSE;
            }
        }
    }


    public class VMDropOntoOperand : VMPrimitiveOperand
    {
        /// <summary>
        /// Gets or sets the source slot mode for the drop onto operation.
        /// </summary>
        public ushort SrcSlotMode { get; set; }

        /// <summary>
        /// Gets or sets the source slot number for the drop onto operation.
        /// </summary>
        public ushort SrcSlotNum { get; set; }

        /// <summary>
        /// Gets or sets the destination slot mode for the drop onto operation.
        /// </summary>
        public ushort DestSlotMode { get; set; }

        /// <summary>
        /// Gets or sets the destination slot number for the drop onto operation.
        /// </summary>
        public ushort DestSlotNum { get; set; }

        #region VMPrimitiveOperand Members

        /// <summary>
        /// Reads the operand data from a byte array.
        /// </summary>
        /// <param name="bytes">The byte array containing the operand data.</param>
        public void Read(byte[] bytes)
        {
            using (var io = IoBuffer.FromBytes(bytes, ByteOrder.LITTLE_ENDIAN))
            {
                SrcSlotMode = io.ReadUInt16();
                SrcSlotNum = io.ReadUInt16();
                DestSlotMode = io.ReadUInt16();
                DestSlotNum = io.ReadUInt16();
            }
        }

        /// <summary>
        /// Writes the operand data to a byte array.
        /// </summary>
        /// <param name="bytes">The byte array to write the operand data to.</param>
        public void Write(byte[] bytes)
        {
            using (var io = new BinaryWriter(new MemoryStream(bytes)))
            {
                io.Write(SrcSlotMode);
                io.Write(SrcSlotNum);
                io.Write(DestSlotMode);
                io.Write(DestSlotNum);
            }
        }

        #endregion
    }
}
