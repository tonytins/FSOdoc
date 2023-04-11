using FSO.Common.Rendering.Framework.IO;
using FSO.Common.Rendering.Framework.Model;
using Microsoft.Xna.Framework;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FSO.Client.UI.Framework
{
    /// <summary>
    /// Represents a utility class for handling double-click events.
    /// </summary>
    public class DoubleClick
    {
        private const int MOUSE_DRIFT_TOLERANCE = 10;

        private long LastClick;
        private Point LastMousePosition;

        /// <summary>
        /// Tries to detect a double-click event based on the provided mouse event type and update state.
        /// </summary>
        /// <param name="type">The type of the mouse event.</param>
        /// <param name="update">The update state containing the mouse state.</param>
        /// <returns>True if a double-click event is detected, false otherwise.</returns>
        public bool TryDoubleClick(UIMouseEventType type, UpdateState update)
        {
            if (type == UIMouseEventType.MouseUp)
            {
                var now = (long)(DateTime.Now - new DateTime(1970, 1, 1)).TotalMilliseconds;
                if (now - LastClick < 500 && IsMouseClose(LastMousePosition, update.MouseState.Position))
                {
                    LastClick = now;
                    LastMousePosition = update.MouseState.Position;
                    return true;
                }
                LastClick = now;
                LastMousePosition = update.MouseState.Position;
            }

            return false;
        }

        /// <summary>
        /// Determines if the current mouse position is close to the previous mouse position within a tolerance limit.
        /// </summary>
        /// <param name="previous">The previous mouse position.</param>
        /// <param name="current">The current mouse position.</param>
        /// <returns>True if the current mouse position is close to the previous mouse position, false otherwise.</returns>
        private bool IsMouseClose(Point previous, Point current)
        {
            return Math.Abs(previous.X - current.X) < MOUSE_DRIFT_TOLERANCE &&
                    Math.Abs(previous.Y - current.Y) < MOUSE_DRIFT_TOLERANCE;
        }
    }
}
