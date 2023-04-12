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
using FSO.SimAntics.Model;
using FSO.SimAntics.Engine.Utils;
using System.IO;

namespace FSO.SimAntics.Primitives
{
    public class VMSetMotiveChange : VMPrimitiveHandler
    {
        /// <summary>
        /// Executes the VMSetMotiveChange primitive.
        /// </summary>
        /// <param name="context">The VMStackFrame context.</param>
        /// <param name="args">The VMPrimitiveOperand arguments.</param>
        /// <returns>The VMPrimitiveExitCode indicating the result of the execution.</returns>
        public override VMPrimitiveExitCode Execute(VMStackFrame context, VMPrimitiveOperand args)
        {
            var operand = (VMSetMotiveChangeOperand)args;
            var avatar = ((VMAvatar)context.Caller);

            if (operand.ClearAll)
            {
                avatar.ClearMotiveChanges();
            }
            else
            {
                var rate = (short)VMMotiveChange.ScaleRate(context.VM, VMMemory.GetVariable(context, (VMVariableScope)operand.DeltaOwner, operand.DeltaData), operand.Motive);
                var MaxValue = VMMemory.GetVariable(context, (VMVariableScope)operand.MaxOwner, operand.MaxData);

                if (operand.Once)
                {
                    var motive = avatar.GetMotiveData(operand.Motive);

                    if (((rate > 0) && (motive > MaxValue)) || ((rate < 0) && (motive < MaxValue)))
                    {
                        return VMPrimitiveExitCode.GOTO_TRUE;
                    }
                    // ^ we're already over, do nothing. (do NOT clamp)

                    motive += rate;
                    if (((rate > 0) && (motive > MaxValue)) || ((rate < 0) && (motive < MaxValue)))
                    {
                        motive = MaxValue;
                    }
                    avatar.SetMotiveData(operand.Motive, motive);
                }
                else
                {
                    avatar.SetMotiveChange(operand.Motive, rate, MaxValue);
                }
            }

            return VMPrimitiveExitCode.GOTO_TRUE;
        }
    }


    /// <summary>
    /// Represents the operand for the VMSetMotiveChange primitive handler.
    /// </summary>
    public class VMSetMotiveChangeOperand : VMPrimitiveOperand
    {
        /// <summary>
        /// Gets or sets the variable scope for the delta value.
        /// </summary>
        public VMVariableScope DeltaOwner { get; set; }

        /// <summary>
        /// Gets or sets the delta data value.
        /// </summary>
        public short DeltaData { get; set; }

        /// <summary>
        /// Gets or sets the variable scope for the maximum value.
        /// </summary>
        public VMVariableScope MaxOwner { get; set; }

        /// <summary>
        /// Gets or sets the maximum data value.
        /// </summary>
        public short MaxData { get; set; }

        /// <summary>
        /// Gets or sets the flags for the VMSetMotiveChange operand.
        /// </summary>
        public VMSetMotiveChangeFlags Flags;

        /// <summary>
        /// Gets or sets the motive for the VMSetMotiveChange operand.
        /// </summary>
        public VMMotive Motive { get; set; }

        /// <summary>
        /// Gets or sets a value indicating whether the ClearAll flag is set.
        /// </summary>
        /// <remarks>
        /// When the ClearAll flag is set, it indicates that all motive changes should be cleared.
        /// </remarks>
        public bool ClearAll
        {
            get
            {
                return (Flags & VMSetMotiveChangeFlags.ClearAll) > 0;
            }
            set
            {
                if (value) Flags |= VMSetMotiveChangeFlags.ClearAll;
                else Flags &= ~VMSetMotiveChangeFlags.ClearAll;
            }
        }

        /// <summary>
        /// Gets or sets a value indicating whether the Once flag is set.
        /// </summary>
        /// <remarks>
        /// When the Once flag is set, it indicates that the motive change should only occur once and then stop.
        /// </remarks>
        public bool Once
        {
            get
            {
                return (Flags & VMSetMotiveChangeFlags.Once) > 0;
            }
            set
            {
                if (value) Flags |= VMSetMotiveChangeFlags.Once;
                else Flags &= ~VMSetMotiveChangeFlags.Once;
            }
        }

        #region VMPrimitiveOperand Members

        /// <summary>
        /// Reads the operand from a byte array.
        /// </summary>
        /// <param name="bytes">The byte array to read from.</param>
        public void Read(byte[] bytes)
        {
            using (var io = IoBuffer.FromBytes(bytes, ByteOrder.LITTLE_ENDIAN))
            {
                DeltaOwner = (VMVariableScope)io.ReadByte();
                MaxOwner = (VMVariableScope)io.ReadByte();
                Motive = (VMMotive)io.ReadByte();
                Flags = (VMSetMotiveChangeFlags)io.ReadByte();

                DeltaData = io.ReadInt16();
                MaxData = io.ReadInt16();
            }
        }

        /// <summary>
        /// Writes the operand to a byte array.
        /// </summary>
        /// <param name="bytes">The byte array to write to.</param>
        public void Write(byte[] bytes)
        {
            using (var io = new BinaryWriter(new MemoryStream(bytes)))
            {
                io.Write((byte)DeltaOwner);
                io.Write((byte)MaxOwner);
                io.Write((byte)Motive);
                io.Write((byte)Flags);
                io.Write(DeltaData);
                io.Write(MaxData);
            }
        }

        #endregion
    }

    [Flags]
    public enum VMSetMotiveChangeFlags
    {
        ClearAll = 1,
        Once = 2,
    }
}
