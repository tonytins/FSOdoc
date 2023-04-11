/*
This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
If a copy of the MPL was not distributed with this file, You can obtain one at
http://mozilla.org/MPL/2.0/.
*/

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Microsoft.Xna.Framework.Graphics;
using FSO.Client.UI.Framework;
using FSO.Client.UI.Model;
using System.IO;
using System.Threading;
using FSO.Client.Utils;
using FSO.Common.Rendering.Framework.Model;
using FSO.Common.Rendering.Framework;
using FSO.Client.GameContent;
using FSO.Client.UI;
using System.Diagnostics;
using Microsoft.Xna.Framework;

namespace FSO.Client
{
    /// <summary>
    /// Central point for accessing game objects
    /// </summary>
    public class GameFacade
    {
        /// <summary>
        /// Represents the content strings used in the game. //todo: cross tso/ts1
        /// </summary>
        public static ContentStrings Strings;

        /// <summary>
        /// Represents the UI layer used in the game.
        /// </summary>
        public static UILayer Screens;

        /// <summary>
        /// Represents the 3D layer used in the game.
        /// </summary>
        public static _3DLayer Scenes;

        /// <summary>
        /// Represents the graphics device used in the game.
        /// </summary>
        public static GraphicsDevice GraphicsDevice;

        /// <summary>
        /// Represents the graphics device manager used in the game.
        /// </summary>
        public static GraphicsDeviceManager GraphicsDeviceManager;

        /// <summary>
        /// Represents the common game object used in the game.
        /// </summary>
        public static Common.Rendering.Framework.Game Game;

        //public static TSOClientTools DebugWindow;

        /// <summary>
        /// Represents the main font used in the game.
        /// </summary>
        public static Font MainFont;

        /// <summary>
        /// Represents the Edith font used in the game.
        /// </summary>
        public static Font EdithFont;

        /// <summary>
        /// Represents the last update state of the game.
        /// </summary>
        public static UpdateState LastUpdateState;

        /// <summary>
        /// Represents the game thread used in the game.
        /// </summary>
        public static Thread GameThread;

        /// <summary>
        /// Represents the focus status of the game.
        /// </summary>
        public static bool Focus = true;

        /// <summary>
        /// Represents the current city name in the game.
        /// </summary>
        public static string CurrentCityName = "";

        /// <summary>
        /// Represents the Linux status of the game.
        /// </summary>
        public static bool Linux;

        /// <summary>
        /// Represents the DirectX status of the game.
        /// </summary>
        public static bool DirectX;

        /// <summary>
        /// Represents the enable mod status of the game.
        /// </summary>
        public static bool EnableMod;

        /// <summary>
        /// Represents the cursor manager used in the game.
        /// </summary>
        public static CursorManager Cursor;

        //Entries received from city server, see UIPacketHandlers.OnCityTokenResponse()

        /// <summary>
        /// Initializes the game facade.
        /// </summary>
        public static void Init()
        {
        }

        /// <summary>
        /// Kills the application.
        /// </summary>
        public static void Kill()
        {
            //TODO: Add any needed deconstruction here.
            Game.Exit();
            Process.GetCurrentProcess().Kill();
        }

        /// <summary>
        /// Gets the game run time as a TimeSpan.
        /// </summary>
        /// <returns>The game run time as a TimeSpan.</returns>
        public static TimeSpan GameRunTime
        {
            get
            {
                if (LastUpdateState != null && LastUpdateState.Time != null)
                {
                    return LastUpdateState.Time.TotalGameTime;
                }
                else
                {
                    return new TimeSpan(0);
                }
            }
        }
    }

    /// <summary>
    /// Represents a basic event handler delegate.
    /// </summary>
    public delegate void BasicEventHandler();
}
