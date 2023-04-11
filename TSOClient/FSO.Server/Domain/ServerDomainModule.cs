using FSO.Common.Domain.Realestate;
using FSO.Common.Domain.Shards;
using FSO.Common.Domain.Top100;
using Ninject.Modules;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
namespace FSO.Server.Domain
{
    /// <summary>
    /// Represents a Ninject module for configuring bindings in the server domain.
    /// </summary>
    public class ServerDomainModule : NinjectModule
    {
        /// <summary>
        /// Loads the module and configures bindings.
        /// </summary>
        public override void Load()
        {
            Bind<IShardsDomain>().To<Shards>().InSingletonScope();
            Bind<IRealestateDomain>().To<FSO.Common.Domain.Realestate.RealestateDomain>().InSingletonScope();
        }
    }
}
