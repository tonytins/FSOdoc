/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
 * If a copy of the MPL was not distributed with this file, You can obtain one at
 * http://mozilla.org/MPL/2.0/. 
 */

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using FSO.SimAntics.NetPlay.Model;
using FSO.SimAntics.NetPlay.Model.Commands;
using FSO.SimAntics.Engine.TSOTransaction;

namespace FSO.SimAntics.NetPlay
{
    /// <summary>
    /// Abstract class that represents a virtual machine network driver.
    /// </summary>
    public abstract class VMNetDriver
    {
        public IVMTSOGlobalLink GlobalLink;

        /// <summary>
        /// Sends a VMNetCommandBodyAbstract command to the network.
        /// </summary>
        /// <param name="cmd">The command to send.</param>
        public abstract void SendCommand(VMNetCommandBodyAbstract cmd);

        /// <summary>
        /// Sends a VMNetCommandBodyAbstract command directly to a specific process ID (PID) on the network.
        /// </summary>
        /// <param name="pid">The process ID (PID) to send the command to.</param>
        /// <param name="cmd">The command to send.</param>
        public abstract void SendDirectCommand(uint pid, VMNetCommandBodyAbstract cmd);

        /// <summary>
        /// Performs a network tick operation on the virtual machine (VM).
        /// </summary>
        /// <param name="vm">The VM to perform the tick on.</param>
        /// <returns>Returns true if the tick was successful, false otherwise.</returns>
        public abstract bool Tick(VM vm);

        /// <summary>
        /// Gets the IP address of a user with a given user ID (UID).
        /// </summary>
        /// <param name="uid">The user ID (UID) of the user.</param>
        /// <returns>Returns the IP address of the user.</returns>
        public abstract string GetUserIP(uint uid);

        public VMCloseNetReason CloseReason;

        /// <summary>
        /// Event that is triggered when a VM-inspired total connection shutdown occurs.
        /// </summary>
        public event VMNetClosedHandler OnShutdown;
        public delegate void VMNetClosedHandler(VMCloseNetReason reason);

        private int DesyncCooldown = 0;
        public uint LastTick = 0;

        /// <summary>
        /// Performs an internal tick operation on the virtual machine (VM) with the provided tick data.
        /// </summary>
        /// <param name="vm">The VM to perform the tick on.</param>
        /// <param name="tick">The tick data to use.</param>
        protected void InternalTick(VM vm, VMNetTick tick)
        {
            if (!tick.ImmediateMode && (tick.Commands.Count == 0 || !(tick.Commands[0].Command is VMStateSyncCmd)) && vm.Context.RandomSeed != tick.RandomSeed)
            {
                if (DesyncCooldown == 0)
                {
                    System.Console.WriteLine("DESYNC - Requested state from host");
                    vm.SendCommand(new VMRequestResyncCmd());
                    DesyncCooldown = 30 * 30;
                }
                else
                {
                    System.Console.WriteLine("WARN - DESYNC - Too soon to try again!");
                }
            }

            vm.Context.RandomSeed = tick.RandomSeed;
            bool doTick = !tick.ImmediateMode;
            foreach (var cmd in tick.Commands)
            {
                if (cmd.Command is VMStateSyncCmd)
                {
                    if (LastTick + 1 != tick.TickID) System.Console.WriteLine("Jump to tick " + tick.TickID);
                    doTick = false;
                }

                var caller = vm.GetAvatarByPersist(cmd.Command.ActorUID);
                cmd.Command.Execute(vm, caller);
            }
            if (tick.TickID < LastTick) System.Console.WriteLine("Tick wrong! Got " + tick.TickID + ", Missed " + ((int)tick.TickID - (LastTick + 1)));
            else if (doTick && vm.Context.Ready)
            {
                if (tick.TickID > LastTick + 1) System.Console.WriteLine("Tick wrong! Got " + tick.TickID + ", Missed " + ((int)tick.TickID - (LastTick + 1)));
#if VM_DESYNC_DEBUG
                vm.Trace.NewTick(tick.TickID);
#endif
                vm.InternalTick(tick.TickID);
                if (DesyncCooldown > 0) DesyncCooldown--;
            }
            LastTick = tick.TickID;
        }
        public virtual void Shutdown()
        {
            if (OnShutdown != null) OnShutdown(CloseReason);
        }

        public delegate void VMNetMessageHandler(VMNetMessageType type, byte[] data);
    }

    public enum VMCloseNetReason
    {
        Unspecified = 0,
        LeaveLot = 1,
        ServerShutdown = 2,
    }
}
