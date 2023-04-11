using FSO.Common.Domain.Shards;
using FSO.Server.Database.DA;
using FSO.Server.Database.DA.Shards;
using FSO.Server.Protocol.CitySelector;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FSO.Server.Domain
{
    /// <summary>
    /// Represents a domain class for managing shards in a server application.
    /// </summary>
    public class Shards : IShardsDomain
    {
        private List<ShardStatusItem> _Shards = new List<ShardStatusItem>();
        private IDAFactory _DbFactory;
        private DateTime _LastPoll;

        /// <summary>
        /// Initializes a new instance of the Shards class with the specified IDAFactory.
        /// </summary>
        /// <param name="factory">The IDAFactory used for accessing the database.</param>
        public Shards(IDAFactory factory)
        {
            _DbFactory = factory;
            Poll();
        }

        /// <summary>
        /// Gets the list of all shards.
        /// </summary>
        public List<ShardStatusItem> All
        {
            get
            {
                return _Shards;
            }
        }

        /// <summary>
        /// Gets the current shard ID, which is not available in the server domain.
        /// </summary>
        public int? CurrentShard
        {
            get
            {
                throw new Exception("CurrentShard not available in server domain");
            }
        }

        /// <summary>
        /// Automatically updates the shard list at regular intervals.
        /// </summary>
        public void AutoUpdate()
        {
            Task.Delay(60000).ContinueWith(x =>
            {
                try
                {
                    Poll();
                }
                catch (Exception ex)
                {
                    // Handle exception
                }
                AutoUpdate();
            });
        }

        private void Poll()
        {
            _LastPoll = DateTime.UtcNow;

            using (var db = _DbFactory.Get())
            {
                _Shards = db.Shards.All().Select(x => new ShardStatusItem()
                {
                    Id = x.shard_id,
                    Name = x.name,
                    Map = x.map,
                    Rank = x.rank,
                    Status = (Server.Protocol.CitySelector.ShardStatus)(byte)x.status,
                    PublicHost = x.public_host,
                    InternalHost = x.internal_host,
                    VersionName = x.version_name,
                    VersionNumber = x.version_number
                }).ToList();
            }
        }

        /// <summary>
        /// Gets a ShardStatusItem by ID.
        /// </summary>
        /// <param name="id">The ID of the shard.</param>
        /// <returns>The ShardStatusItem with the specified ID, or null if not found.</returns>
        public ShardStatusItem GetById(int id)
        {
            return _Shards.FirstOrDefault(x => x.Id == id);
        }

        /// <summary>
        /// Gets a ShardStatusItem by name.
        /// </summary>
        /// <param name="name">The name of the shard.</param>
        /// <returns>The ShardStatusItem with the specified name, or null if not found.</returns>
        public ShardStatusItem GetByName(string name)
        {
            return _Shards.FirstOrDefault(x => x.Name == name);
        }
    }
}
