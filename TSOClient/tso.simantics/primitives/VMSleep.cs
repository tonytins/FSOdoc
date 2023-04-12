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
    /// <summary>
    /// Represents a primitive handler for the VMSleep primitive.
    /// </summary>
    public class VMSleep : VMPrimitiveHandler
    {
        /// <summary>
        /// Executes the VMSleep primitive.
        /// </summary>
        /// <param name="context">The VMStackFrame context.</param>
        /// <param name="args">The VMPrimitiveOperand arguments.</param>
        /// <returns>The VMPrimitiveExitCode.</returns>
        public override VMPrimitiveExitCode Execute(VMStackFrame context, VMPrimitiveOperand args)
        {
            var operand = (VMSleepOperand)args;
            var idleStart = context.Thread.ScheduleIdleStart;

            // Decrease the value of the specified stack variable by the difference between current tick and idle start, or 1 if idle start is not set.
            context.Args[operand.StackVarToDec] -= (short)((idleStart != 0 && idleStart < context.VM.Scheduler.CurrentTickID) ? (context.VM.Scheduler.CurrentTickID - idleStart) : 1);

            if (context.Thread.Interrupt)
            {
                // If the thread is interrupted, reset idle start and interrupt flags and return GOTO_TRUE.
                context.Thread.ScheduleIdleStart = 0;
                context.Thread.Interrupt = false;
                return VMPrimitiveExitCode.GOTO_TRUE;
            }

            if (context.Args[operand.StackVarToDec] == -1)
            {
                // If the value of the stack variable is -1, reset idle start, generate a random number for desync detection, and return GOTO_TRUE.
                context.Thread.ScheduleIdleStart = 0;
                context.VM.Context.NextRandom(1); //rng cycle - for desync detect
                return VMPrimitiveExitCode.GOTO_TRUE;
            }
            else
            {
                // If the value of the stack variable is not -1, set idle start to current tick, schedule a future tick, and return CONTINUE_FUTURE_TICK.
                context.Thread.ScheduleIdleStart = context.VM.Scheduler.CurrentTickID;
                context.VM.Scheduler.ScheduleTickIn(context.Caller, (uint)context.Args[operand.StackVarToDec] + 1);
                return VMPrimitiveExitCode.CONTINUE_FUTURE_TICK;
            }
        }
    }

    /// <summary>
    /// Represents the operand for the VMSleep primitive.
    /// </summary>
    public class VMSleepOperand : VMPrimitiveOperand
    {
        /// <summary>
        /// Gets or sets the stack variable to decrement.
        /// </summary>
        public short StackVarToDec { get; set; }

        #region VMPrimitiveOperand Members

        /// <summary>
        /// Reads the operand from a byte array.
        /// </summary>
        /// <param name="bytes">The byte array.</param>
        public void Read(byte[] bytes)
        {
            using (var io = IoBuffer.FromBytes(bytes, ByteOrder.LITTLE_ENDIAN))
            {
                StackVarToDec = io.ReadInt16();
            }
        }

        /// <summary>
        /// Writes the operand to a byte array.
        /// </summary>
        /// <param name="bytes">The byte array.</param>
        public void Write(byte[] bytes)
        {
            using (var io = new BinaryWriter(new MemoryStream(bytes)))
            {
                io.Write(StackVarToDec);
            }
        }

        #endregion
    }
}
