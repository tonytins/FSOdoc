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
using FSO.SimAntics.Model;
using System.IO;

namespace FSO.SimAntics.Primitives
{
    public class VMIdleForInput : VMPrimitiveHandler
    {
        public override VMPrimitiveExitCode Execute(VMStackFrame context, VMPrimitiveOperand args) //TODO: Behaviour for being notified out of idle and interaction canceling
        {
            var operand = (VMIdleForInputOperand)args;
            var idleStart = context.Thread.ScheduleIdleStart;
            context.Thread.ScheduleIdleStart = 0;

            context.Args[operand.StackVarToDec] -= (short)((idleStart != 0 && idleStart < context.VM.Scheduler.CurrentTickID) ? (context.VM.Scheduler.CurrentTickID - idleStart) : 1);

            //if we're main, attempt to run a queued interaction. We just idle if this fails.
            if (operand.AllowPush == 1 && !context.ActionTree && context.Thread.AttemptPush())
            {
                return VMPrimitiveExitCode.CONTINUE_NEXT_TICK; //control handover
                //TODO: does this forcefully end the rest of the idle? (force a true return, must loop back to run again)
            }

            if ((context.ActionTree && context.Thread.Queue[0].Cancelled) || (!context.ActionTree && context.Thread.Queue.Count > 0))
            {
                context.Caller.SetFlag(VMEntityFlags.NotifiedByIdleForInput, true);
                return VMPrimitiveExitCode.GOTO_TRUE;
            }

            if (context.Thread.Interrupt)
            {
                context.Thread.Interrupt = false;
                return VMPrimitiveExitCode.GOTO_TRUE;
            }

            if (context.Args[operand.StackVarToDec] < 0)
            {
                return VMPrimitiveExitCode.GOTO_TRUE;
            }
            else
            {
                if (operand.AllowPush == 1) return VMPrimitiveExitCode.CONTINUE_NEXT_TICK; //interactions must be checked every tick
                else
                {
                    context.Thread.ScheduleIdleStart = context.VM.Scheduler.CurrentTickID;
                    context.VM.Scheduler.ScheduleTickIn(context.Caller, (uint)context.Args[operand.StackVarToDec] + 1);
                    return VMPrimitiveExitCode.CONTINUE_FUTURE_TICK;
                }
            }
        }
    }

    public class VMIdleForInputOperand : VMPrimitiveOperand
    {
        /// <summary>
        /// Gets or sets the stack variable to decrement.
        /// </summary>
        public short StackVarToDec { get; set; }

        /// <summary>
        /// Gets or sets the value indicating whether push is allowed.
        /// </summary>
        public ushort AllowPush { get; set; }

        #region VMPrimitiveOperand Members

        /// <summary>
        /// Reads the operand from a byte array.
        /// </summary>
        /// <param name="bytes">The byte array to read from.</param>
        public void Read(byte[] bytes)
        {
            using (var io = IoBuffer.FromBytes(bytes, ByteOrder.LITTLE_ENDIAN))
            {
                // Read StackVarToDec from the byte array
                StackVarToDec = io.ReadInt16();

                // Read AllowPush from the byte array
                AllowPush = io.ReadUInt16();
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
                // Write StackVarToDec to the byte array
                io.Write(StackVarToDec);

                // Write AllowPush to the byte array
                io.Write(AllowPush);
            }
        }

        #endregion
    }

}
