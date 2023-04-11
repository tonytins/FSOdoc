using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Drawing;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using FSO.Client.UI.Framework;
using FSO.Client;

namespace FSO.IDE.Common
{
    /// <summary>
    /// Represents a partial class for the AvatarAnimatorControl, which is a FSOUIControl used to display avatar animations.
    /// </summary>
    public partial class AvatarAnimatorControl : FSOUIControl
    {
        private UIAvatarAnimator Renderer;

        /// <summary>
        /// Shows the specified animation on the AvatarAnimatorControl.
        /// </summary>
        /// <param name="anim">The name of the animation to show.</param>
        public void ShowAnim(string anim)
        {
            if (FSOUI == null)
            {
                var mainCont = new UIExternalContainer(128, 128);
                Renderer = new UIAvatarAnimator();
                mainCont.Add(Renderer);
                GameFacade.Screens.AddExternal(mainCont);

                SetUI(mainCont);
            }
            Renderer.SetAnimation(anim);
        }
    }
}
