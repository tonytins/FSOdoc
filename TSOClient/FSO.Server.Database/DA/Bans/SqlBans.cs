using Dapper;
using FSO.Server.Database.DA.Bans;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FSO.Server.Database.DA.Bans
{
    /// <summary>
    /// Represents a SQL data access class for managing bans.
    /// </summary>
    public class SqlBans : AbstractSqlDA, IBans
    {
        public SqlBans(ISqlContext context) : base(context)
        {
        }

        /// <summary>
        /// Gets the ban information for the given IP address.
        /// </summary>
        /// <param name="ip">The IP address to search for bans.</param>
        /// <returns>The DbBan object representing the ban information for the given IP address.</returns>
        public DbBan GetByIP(string ip)
        {
            return Context.Connection.Query<DbBan>("SELECT * FROM fso_ip_ban WHERE ip_address = @ip", new { ip = ip }).FirstOrDefault();
        }

        /// <summary>
        /// Adds a new ban to the database.
        /// </summary>
        /// <param name="ip">The IP address to be banned.</param>
        /// <param name="userid">The ID of the user to be banned.</param>
        /// <param name="reason">The reason for the ban.</param>
        /// <param name="enddate">The end date of the ban.</param>
        /// <param name="client_id">The ID of the client initiating the ban.</param>
        public void Add(string ip, uint userid, string reason, int enddate, string client_id)
        {
            Context.Connection.Execute(
                "REPLACE INTO fso_ip_ban (user_id, ip_address, banreason, end_date, client_id) " +
                "VALUES (@user_id, @ip_address, @banreason, @end_date, @client_id)",
                new
                {
                    user_id = userid,
                    ip_address = ip,
                    banreason = reason,
                    end_date = enddate,
                    client_id = client_id
                }
            );
        }
    }
}
