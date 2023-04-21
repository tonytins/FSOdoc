using Dapper;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FSO.Server.Database.DA.Hosts
{
    /// <summary>
    /// Represents a class for managing hosts using SQL data access.
    /// </summary>
    public class SqlHosts : AbstractSqlDA, IHosts
    {
        public SqlHosts(ISqlContext context) : base(context)
        {
        }

        /// <summary>
        /// Retrieves all hosts from the database.
        /// </summary>
        /// <returns>An IEnumerable containing all hosts in the database.</returns>
        public IEnumerable<DbHost> All()
        {
            return Context.Connection.Query<DbHost>("SELECT * FROM fso_hosts");
        }

        /// <summary>
        /// Creates a new host or replaces an existing host in the database.
        /// </summary>
        /// <param name="host">The host to create or replace.</param>
        public void CreateHost(DbHost host)
        {
            Context.Connection.Execute(
                "REPLACE INTO fso_hosts (call_sign, role, status, internal_host, public_host, time_boot, shard_id) " +
                "VALUES (@call_sign, @role, @status, @internal_host, @public_host, @time_boot, @shard_id)",
                new
                {
                    call_sign = host.call_sign,
                    role = host.role.ToString(),
                    status = host.status.ToString(),
                    internal_host = host.internal_host,
                    public_host = host.public_host,
                    time_boot = host.time_boot,
                    shard_id = host.shard_id
                }
            );
        }

        /// <summary>
        /// Retrieves a specific host from the database based on its call sign.
        /// </summary>
        /// <param name="call_sign">The call sign of the host to retrieve.</param>
        /// <returns>The host with the specified call sign, or null if no such host exists.</returns>
        public DbHost Get(string call_sign)
        {
            throw new NotImplementedException();
        }

        /// <summary>
        /// Sets the status of a specific host in the database based on its call sign.
        /// </summary>
        /// <param name="call_sign">The call sign of the host to update.</param>
        /// <param name="status">The new status of the host.</param>
        public void SetStatus(string call_sign, DbHostStatus status)
        {
            Context.Connection.Execute("UPDATE fso_hosts SET status = @status WHERE call_sign = @call_sign", new
            {
                call_sign = call_sign,
                status = status.ToString()
            });
        }
    }
}
