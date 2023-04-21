using Dapper;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FSO.Server.Database.DA.LotVisitors
{
    /// <summary>
    /// This class is an implementation of the ILotVisits interface and is responsible for managing lot visits
    /// in the database through executing SQL queries on the given ISqlContext.
    /// </summary>
    public class SqlLotVisits : AbstractSqlDA, ILotVisits
    {
        /// <summary>
        /// Adds a new lot visit to the database with the specified avatar, lot, and visitor type.
        /// </summary>
        /// <param name="avatar_id">The ID of the avatar visiting the lot.</param>
        /// <param name="visitor_type">The type of visitor (such as "lot_owner" or "lot_visitor").</param>
        /// <param name="lot_id">The ID of the lot being visited.</param>
        /// <returns>The ID of the newly created lot visit, or null if an error occurred.</returns>
        public int? Visit(uint avatar_id, DbLotVisitorType visitor_type, int lot_id)
        {
            try
            {
                //Stored procedure will handle erroring any active visits that should no longer be active
                return Context.Connection.Query<int>("SELECT `fso_lot_visits_create`(@avatar_id, @lot_id, @type)", new
                {
                    avatar_id = avatar_id,
                    lot_id = lot_id,
                    type = visitor_type.ToString()
                }).First();
            }
            catch (Exception ex)
            {
                return null;
            }
        }

        /// <summary>
        /// Marks the specified lot visit as "closed" in the database.
        /// </summary>
        /// <param name="visit_id">The ID of the lot visit to mark as closed.</param>
        public void Leave(int visit_id)
        {
            try
            {
                Context.Connection.Query("UPDATE `fso_lot_visits` SET status = 'closed', time_closed = current_timestamp WHERE lot_visit_id = @visit_id AND `status` = 'active'", new { visit_id = visit_id });
            }
            catch (Exception ex)
            {
            }
        }

        /// <summary>
        /// Renews the specified lot visits by updating their "time_closed" field to the current timestamp.
        /// </summary>
        /// <param name="visit_ids">The IDs of the lot visits to renew.</param>
        public void Renew(IEnumerable<int> visit_ids)
        {
            try
            {
                Context.Connection.Query("UPDATE `fso_lot_visits` SET time_closed = current_timestamp WHERE lot_visit_id IN @visit_ids AND `status` = 'active'", new { visit_ids = visit_ids });
            }
            catch (Exception ex)
            {
            }
        }

        /// <summary>
        /// Purges all lot visits from the database that were closed before the specified date, as well as
        /// all active lot visits that were created before the specified date.
        /// </summary>
        /// <param name="date">The date to purge lot visits before.</param>
        public void PurgeByDate(DateTime date)
        {
            Context.Connection.Query("DELETE FROM `fso_lot_visits` WHERE time_closed IS NOT NULL AND time_closed < @date", new { date = date });
            Context.Connection.Query("DELETE FROM `fso_lot_visits` WHERE time_closed IS NULL AND time_created < @date", new { date = date });
        }

        public IEnumerable<DbLotVisit> StreamBetween(int shard_id, DateTime start, DateTime end)
        {
            return Context.Connection.Query<DbLotVisit>(
                "SELECT * FROM `fso_lot_visits` v INNER JOIN fso_lots l ON v.lot_id = l.lot_id " +
                    "WHERE l.shard_id = @shard_id AND status != 'failed' " +
                    "AND time_closed IS NOT NULL " +
                    "AND type = 'visitor' " +
                    "AND (time_created BETWEEN @start AND @end OR time_closed BETWEEN @start and @end)",
                new { start = start, end = end, shard_id = shard_id }, buffered: false);
        }
    }
}
