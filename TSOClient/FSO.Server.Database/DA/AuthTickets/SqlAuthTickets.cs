using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Dapper;
using FSO.Server.Common;

namespace FSO.Server.Database.DA.AuthTickets
{
    /// <summary>
    /// Represents a class for interacting with authentication tickets in a SQL database.
    /// </summary>
    public class SqlAuthTickets : AbstractSqlDA, IAuthTickets
    {
        /// <summary>
        /// Initializes a new instance of the <see cref="SqlAuthTickets"/> class with the specified SQL context.
        /// </summary>
        /// <param name="context">The SQL context to use for database interactions.</param>
        public SqlAuthTickets(ISqlContext context) : base(context)
        {
        }

        /// <summary>
        /// Creates a new authentication ticket in the database.
        /// </summary>
        /// <param name="ticket">The authentication ticket to create.</param>
        public void Create(AuthTicket ticket)
        {
            Context.Connection.Execute("INSERT INTO fso_auth_tickets VALUES (@ticket_id, @user_id, @date, @ip)", ticket);
        }

        /// <summary>
        /// Deletes the authentication ticket with the specified ID from the database.
        /// </summary>
        /// <param name="id">The ID of the authentication ticket to delete.</param>
        public void Delete(string id)
        {
            Context.Connection.Execute("DELETE FROM fso_auth_tickets WHERE ticket_id = @ticket_id", new { ticket_id = id });
        }

        /// <summary>
        /// Retrieves the authentication ticket with the specified ID from the database.
        /// </summary>
        /// <param name="id">The ID of the authentication ticket to retrieve.</param>
        /// <returns>The authentication ticket with the specified ID, or null if no such ticket exists.</returns>
        public AuthTicket Get(string id)
        {
            return
                Context.Connection.Query<AuthTicket>("SELECT * FROM fso_auth_tickets WHERE ticket_id = @ticket_id", new { ticket_id = id }).FirstOrDefault();
        }

        /// <summary>
        /// Deletes all authentication tickets from the database that are older than the specified time.
        /// </summary>
        /// <param name="time">The time (in seconds since the Unix epoch) before which all authentication tickets should be deleted.</param>
        public void Purge(uint time)
        {
            Context.Connection.Execute("DELETE FROM fso_auth_tickets WHERE date < @time", new { time = time });
        }
    }
}
