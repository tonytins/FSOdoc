/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
 * If a copy of the MPL was not distributed with this file, You can obtain one at
 * http://mozilla.org/MPL/2.0/. 
 */

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Microsoft.Xna.Framework;
using FSO.SimAntics.Marshals;

namespace FSO.SimAntics
{
    /// <summary>
    /// Represents a virtual machine clock used for timekeeping in a simulation.
    /// </summary>
    public class VMClock
    {
        /// <summary>
        /// Gets or sets the total number of ticks.
        /// </summary>
        public long Ticks;

        /// <summary>
        /// Gets or sets the current number of minute fractions.
        /// </summary>
        public int MinuteFractions;

        /// <summary>
        /// Gets or sets the number of ticks per minute.
        /// </summary>
        public int TicksPerMinute;

        /// <summary>
        /// Gets or sets the current number of minutes.
        /// </summary>
        public int Minutes;

        /// <summary>
        /// Gets or sets the current number of hours.
        /// </summary>
        public int Hours;

        /// <summary>
        /// Gets or sets the current fire percentage.
        /// </summary>
        public int FirePercent;

        /// <summary>
        /// Gets the current time of day.
        /// </summary>
        /// <remarks>
        /// The time of day is represented as an integer, where 0 represents daytime and 1 represents nighttime.
        /// </remarks>
        public int TimeOfDay
        {
            get
            {
                //return (Hours >= 6 && Hours < 18) ? 0 : 1;
                return 0; //TODO: hack to make windows always cast full contribution. need to look into real patch.
            }
        }

        /// <summary>
        /// Gets the current number of seconds.
        /// </summary>
        public int Seconds
        {
            get
            {
                return ((MinuteFractions * 60) / TicksPerMinute);
            }
        }

        /// <summary>
        /// Advances the clock by one tick.
        /// </summary>
        public void Tick()
        {
            if (FirePercent < 20000) FirePercent++;
            if (++MinuteFractions >= TicksPerMinute)
            {
                MinuteFractions = 0;
                if (++Minutes >= 60)
                {
                    Minutes = 0;
                    if (++Hours >= 24)
                    {
                        Hours = 0;
                    }
                }
            }
            this.Ticks++;
        }

        /// <summary>
        /// Initializes a new instance of the VMClock class.
        /// </summary>
        public VMClock() { }

        #region VM Marshalling Functions
        /// <summary>
        /// Saves the current state of the VMClock to a VMClockMarshal object.
        /// </summary>
        /// <returns>A VMClockMarshal object representing the current state of the VMClock.</returns>
        public virtual VMClockMarshal Save()
        {
            return new VMClockMarshal
            {
                Ticks = Ticks,
                MinuteFractions = MinuteFractions,
                TicksPerMinute = TicksPerMinute,
                Minutes = Minutes,
                Hours = Hours,
                FirePercent = FirePercent
            };
        }

        /// <summary>
        /// Loads the state of the VMClock from a VMClockMarshal object.
        /// </summary>
        /// <param name="input">The VMClockMarshal object containing the state of the VMClock.</param>
        public virtual void Load(VMClockMarshal input)
        {
            Ticks = input.Ticks;
            MinuteFractions = input.MinuteFractions;
            TicksPerMinute = input.TicksPerMinute;
            Minutes = input.Minutes;
            Hours = input.Hours;
            FirePercent = input.FirePercent;
        }


        public VMClock(VMClockMarshal input)
        {
            Load(input);
        }
        #endregion
    }
}
