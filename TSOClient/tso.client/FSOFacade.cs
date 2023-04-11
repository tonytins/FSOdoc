using FSO.Client.UI.Panels;
using Ninject;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FSO.Client
{
    /// <summary>
    /// Represents the facade class for the FSO client, providing access to various controllers and kernel.
    /// </summary>
    public class FSOFacade
    {
        /// <summary>
        /// Gets or sets the instance of the KernelBase for the FSO client.
        /// </summary>
        public static KernelBase Kernel;

        /// <summary>
        /// Gets or sets the instance of the GameController for the FSO client.
        /// </summary>
        public static GameController Controller;

        /// <summary>
        /// Gets or sets the instance of the UIMessageController for the FSO client, which handles UI messages.
        /// </summary>
        public static UIMessageController MessageController = new UIMessageController();
    }
}
