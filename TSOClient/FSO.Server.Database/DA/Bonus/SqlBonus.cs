using Dapper;
using FSO.Server.Database.DA.Utils;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FSO.Server.Database.DA.Bonus
{
    /// <summary>
    /// Represents a SQL data access class for managing bonus payments.
    /// </summary>
    public class SqlBonus : AbstractSqlDA, IBonus
    {
        public SqlBonus(ISqlContext context) : base(context)
        {
        }

        /// <summary>
        /// Gets the bonus payment information for the given avatar ID.
        /// </summary>
        /// <param name="avatar_id">The ID of the avatar to search for bonus payments.</param>
        /// <returns>The list of DbBonus objects representing the bonus payment information for the given avatar ID.</returns>
        public IEnumerable<DbBonus> GetByAvatarId(uint avatar_id)
        {
            return Context.Connection.Query<DbBonus>("SELECT * FROM fso_bonus WHERE avatar_id = @avatar_id ORDER BY period DESC LIMIT 14", new { avatar_id = avatar_id });
        }

        /// <summary>
        /// Gets the bonus payment metrics for the given date and shard ID.
        /// </summary>
        /// <param name="date">The date to search for bonus payment metrics.</param>
        /// <param name="shard_id">The ID of the shard to search for bonus payment metrics.</param>
        /// <returns>The list of DbBonusMetrics objects representing the bonus payment metrics for the given date and shard ID.</returns>
        public IEnumerable<DbBonusMetrics> GetMetrics(DateTime date, int shard_id)
        {
            return Context.Connection.Query<DbBonusMetrics>(
                @"SELECT * FROM (
	            SELECT a.avatar_id, 
			             r.lot_id,
		             (SELECT lvt.minutes from fso_lot_visit_totals lvt where lvt.lot_id = r.lot_id AND lvt.date = CAST(@p_date as DATE)) as visitor_minutes,
		             (SELECT rank from fso_lot_top_100 lt100 WHERE lt100.lot_id = r.lot_id) as property_rank,
		             NULL as sim_rank
	            FROM fso_avatars a
		            LEFT JOIN fso_roommates r ON r.avatar_id = a.avatar_id
	            WHERE a.shard_id = @p_shard_id
            ) as bonusPayments 
	            WHERE visitor_minutes IS NOT NULL
	             OR  property_rank IS NOT NULL
	             OR  sim_rank IS NOT NULL"
            , new { p_date = date, p_shard_id = shard_id }, buffered: false);
        }

        /// <summary>
        /// Inserts the given bonus payment information into the database.
        /// </summary>
        /// <param name="bonus">The list of DbBonus objects representing the bonus payment information to insert.</param>
        public void Insert(IEnumerable<DbBonus> bonus)
        {
            Context.Connection.ExecuteBufferedInsert("INSERT INTO fso_bonus (avatar_id, period, bonus_visitor, bonus_property, bonus_sim) VALUES (@avatar_id, @period, @bonus_visitor, @bonus_property, @bonus_sim) ON DUPLICATE KEY UPDATE fso_bonus.avatar_id = fso_bonus.avatar_id", bonus, 100);
        }

        /// <summary>
        /// Purges the bonus payment information for periods before the given date.
        /// </summary>
        /// <param name="date">The date to purge bonus payment information before.</param>
        public void Purge(DateTime date)
        {
            Context.Connection.Execute("DELETE FROM fso_bonus WHERE period < @date", new { date = date });
        }
    }
}
