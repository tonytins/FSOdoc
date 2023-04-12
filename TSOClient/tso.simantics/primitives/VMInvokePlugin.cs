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
using FSO.SimAntics.Model;
using FSO.SimAntics.NetPlay.EODs.Model;
using FSO.SimAntics.Engine.Scopes;

namespace FSO.SimAntics.Primitives
{
    public class VMInvokePlugin : VMPrimitiveHandler
    {
        public static readonly HashSet<uint> IdleEvents = new HashSet<uint>()
        {
            0x2a6356a0,
            0x4a5be8ab,
            0xea47ae39,

            0x2b58020b, //rack owner
            0xcb492685, //rack
            0x8b300068, //dresser
            0x0949E698, //scoreboard
        };

        /// <summary>
        /// Executes the plugin logic.
        /// </summary>
        /// <param name="context">The VMStackFrame context.</param>
        /// <param name="args">The VMPrimitiveOperand arguments.</param>
        /// <returns>The VMPrimitiveExitCode indicating the result of the execution.</returns>
        public override VMPrimitiveExitCode Execute(VMStackFrame context, VMPrimitiveOperand args)
        {
            //this probably shouldn't use an AsyncWaitState. I can see this having its own state.
            var operand = (VMInvokePluginOperand)args;

            var localEvt = context.Locals[operand.EventLocal];
            if (localEvt < 0)
            {
                if (context.VM.EODHost != null) context.VM.EODHost.ForceDisconnectObj(context.Caller);
                context.Thread.EODConnection = null;
            }

            if (context.Thread.EODConnection != null)
            {
                // If EODConnection is not null, it means a connection has already been established
                // for this plugin invocation.

                if (context.VM.EODHost != null)
                {
                    // Notify the EODHost to deliver the local event to the caller.
                    context.VM.EODHost.SimanticsDeliver(localEvt, context.Caller);
                }

                var eodState = context.Thread.EODConnection;
                while (eodState.Events.Count > 0)
                {
                    // Pop off an event from the events queue.
                    var evt = eodState.Events[0];
                    eodState.Events.RemoveAt(0);
                    if (evt.Code < 0) continue;

                    // Set the local event code and copy the event data to temp registers.
                    context.Locals[operand.EventLocal] = evt.Code;
                    for (int i = 0; i < evt.Data.Length; i++)
                    {
                        context.Thread.TempRegisters[i] = evt.Data[i];
                    }

                    // Return GOTO_FALSE to indicate event processing should continue in the next tick.
                    return VMPrimitiveExitCode.GOTO_FALSE;
                }

                if (eodState.Ended)
                {
                    // If the EOD state has ended, reset the EODConnection and return GOTO_TRUE
                    // to indicate the event has been fully processed.
                    context.Thread.EODConnection = null;
                    return VMPrimitiveExitCode.GOTO_TRUE;
                }
            }
            else if (context.Locals[operand.EventLocal] == -2)
            {
                // If EODConnection is null and local event is -2, it means a connection needs to be initiated.

                var objID = context.Locals[operand.ObjectLocal];
                var personID = context.Locals[operand.PersonLocal];

                if (operand.Joinable)
                {
                    // If the plugin invocation is joinable, check if the target object has a server,
                    // and create one if it doesn't.
                    var serverObj = context.VM.GetObjectById(objID);
                    if (serverObj == null) return VMPrimitiveExitCode.GOTO_TRUE; //no server
                    if (serverObj.Thread.EODConnection == null)
                    {
                        // Connect the server object by creating a new EODPluginThreadState.
                        serverObj.Thread.EODConnection = new VMEODPluginThreadState()
                        {
                            ObjectID = objID,
                            AvatarID = 0,
                            Joinable = true,
                            Ended = false
                        };

                        if (context.VM.IsServer)
                        {
                            // Notify the EODHost to connect the server object.
                            context.VM.EODHost.Connect(operand.PluginID, serverObj, serverObj, null, true, context.VM);
                        }
                    }
                }

                // Create a new EODPluginThreadState for the caller object and initiate the connection.
                context.Thread.EODConnection = new VMEODPluginThreadState()
                {
                    ObjectID = objID,
                    AvatarID = personID,
                    Joinable = operand.Joinable,
                    Ended = false
                };
                if (context.VM.IsServer)
                {
                    context.VM.EODHost.Connect(operand.PluginID, context.Caller,
                        context.VM.GetObjectById(objID),
                        (VMAvatar)context.VM.GetObjectById(personID),
                        operand.Joinable,
                        context.VM
                        );
                }

            }
            else
            {
                return VMPrimitiveExitCode.GOTO_TRUE;
            }

            context.Locals[operand.EventLocal] = 0;

            context.Thread.TempRegisters[0] = 0;
            return VMPrimitiveExitCode.GOTO_FALSE_NEXT_TICK;
            /*
            if (IdleEvents.Contains(operand.PluginID))
            {

            }
            else return VMPrimitiveExitCode.CONTINUE_NEXT_TICK;
            */
        }
    }

    /// <summary>
    /// Represents the operand for the VMInvokePlugin primitive handler, which is responsible
    /// for handling plugin invocations in the virtual machine.
    /// </summary>
    public class VMInvokePluginOperand : VMPrimitiveOperand
    {
        /// <summary>
        /// Gets or sets the local variable index for the person object ID.
        /// </summary>
        public byte PersonLocal;

        /// <summary>
        /// Gets or sets the local variable index for the object ID.
        /// </summary>
        public byte ObjectLocal;

        /// <summary>
        /// Gets or sets the local variable index for the target event ID, where the values go in temp0.
        /// </summary>
        public byte EventLocal;

        /// <summary>
        /// Gets or sets a value indicating whether the plugin invocation is joinable.
        /// </summary>
        public bool Joinable;

        /// <summary>
        /// Gets or sets the plugin ID for the invocation.
        /// </summary>
        public uint PluginID;

        //sign: 0x2a6356a0
        //dancefloor: 0x4a5be8ab
        //pizza: 0xea47ae39

        #region VMPrimitiveOperand Members

        /// <summary>
        /// Reads the operand from the specified byte array.
        /// </summary>
        /// <param name="bytes">The byte array to read from.</param>
        public void Read(byte[] bytes)
        {
            using (var io = IoBuffer.FromBytes(bytes, ByteOrder.LITTLE_ENDIAN))
            {
                PersonLocal = io.ReadByte();
                ObjectLocal = io.ReadByte();
                EventLocal = io.ReadByte();
                Joinable = io.ReadByte() > 0;

                PluginID = io.ReadUInt32();
            }
        }

        /// <summary>
        /// Writes the operand to the specified byte array.
        /// </summary>
        /// <param name="bytes">The byte array to write to.</param>
        public void Write(byte[] bytes)
        {
            // Writing the operand is not implemented, as it is not used in this context.
            // This method is required by the VMPrimitiveOperand interface.
        }

        #endregion
    }

}
