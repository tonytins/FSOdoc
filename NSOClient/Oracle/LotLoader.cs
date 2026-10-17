/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
 * If a copy of the MPL was not distributed with this file, You can obtain one at
 * http://mozilla.org/MPL/2.0/.
 */

using System.Collections.Generic;
using System.IO;
using FSO.LotView.Model;
using FSO.SimAntics;
using FSO.SimAntics.Engine;
using FSO.SimAntics.Model;
using FSO.SimAntics.Utils;

namespace FSO.Oracle
{
    /// <summary>
    /// Loads blueprint XML into a VM the way <c>VMBlueprintRestoreCmd</c> and
    /// <c>VMWorldActivator.LoadFromXML</c> do, with one change: the new context is seeded.
    /// </summary>
    /// <remarks>
    /// <c>LoadFromXML</c> replaces the VM's context, and a new <c>VMContext</c> seeds its random
    /// generator from an unseeded <c>System.Random</c>. Every draw made while the lot's objects
    /// are created (their init routines) and on the tick that runs the load would differ from run
    /// to run. This copy seeds the new context as soon as it exists; everything else, in the
    /// same order, is FreeSO's (headless, so no blueprint, terrain, or ambience; no floor clip,
    /// offset, or target size).
    /// </remarks>
    public static class LotLoader
    {
        public static void Load(VM vm, byte[] xml, ulong seed)
        {
            // VMBlueprintRestoreCmd.Execute, with JobLevel -1.
            vm.SetGlobalValue(11, -1);
            XmlHouseData model;
            using (var stream = new MemoryStream(xml)) model = XmlHouseData.Parse(stream);

            // VMWorldActivator.LoadFromXML.
            var size = model.Size;
            vm.Entities = new List<VMEntity>();
            vm.Scheduler = new VMScheduler(vm);
            vm.Context = new VMContext(vm.Context.World);
            vm.Context.RandomSeed = seed;  // the one change
            vm.Context.VM = vm;
            vm.Context.Blueprint = null;
            vm.Context.Architecture = new VMArchitecture(size, size, null, vm.Context);
            var arch = vm.Context.Architecture;

            foreach (var floor in model.World.Floors)
                arch.SetFloor((short)floor.X, (short)floor.Y, (sbyte)(floor.Level + 1), new FloorTile { Pattern = (ushort)floor.Value }, true);
            foreach (var pool in model.World.Pools)
                arch.SetFloor((short)pool.X, (short)pool.Y, 1, new FloorTile { Pattern = 65535 }, true);
            foreach (var wall in model.World.Walls)
            {
                arch.SetWall((short)wall.X, (short)wall.Y, (sbyte)(wall.Level + 1), new WallTile
                {
                    Segments = wall.Segments,
                    TopLeftPattern = (ushort)wall.TopLeftPattern,
                    TopRightPattern = (ushort)wall.TopRightPattern,
                    BottomLeftPattern = (ushort)wall.BottomLeftPattern,
                    BottomRightPattern = (ushort)wall.BottomRightPattern,
                    TopLeftStyle = (ushort)wall.LeftStyle,
                    TopRightStyle = (ushort)wall.RightStyle
                });
            }
            arch.RegenRoomMap();
            vm.Context.RegeneratePortalInfo();

            var activator = new VMWorldActivator(vm, vm.Context.World);
            foreach (var obj in model.Objects) activator.CreateObject(obj);

            arch.SignalTerrainRedraw();
            arch.Tick();
        }
    }
}
