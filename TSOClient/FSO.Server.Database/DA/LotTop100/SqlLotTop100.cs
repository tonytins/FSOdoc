using Dapper;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using FSO.Common.Enum;

namespace FSO.Server.Database.DA.LotTop100
{
    /// <summary>
    /// Represents a class that handles SQL queries related to the LotTop100 table.
    /// </summary>
    public class SqlLotTop100 : AbstractSqlDA, ILotTop100
    {
        public SqlLotTop100(ISqlContext context) : base(context)
        {
        }

        /// <summary>
        /// Returns all records from the LotTop100 table, including the lot name and location.
        /// </summary>
        public IEnumerable<DbLotTop100> All()
        {
            return Context.Connection.Query<DbLotTop100>("SELECT top.*, l.name as lot_name, l.location as lot_location FROM fso_lot_top_100 top LEFT JOIN fso_lots l ON top.lot_id = l.lot_id");
        }

        /// <summary>
        /// Calculates the top 100 lots for the given date and shard ID.
        /// </summary>
        /// <param name="date">The date for which to calculate the top 100 lots.</param>
        /// <param name="shard_id">The shard ID for which to calculate the top 100 lots.</param>
        /// <returns>True if the calculation was successful, false otherwise.</returns>
        public bool Calculate(DateTime date, int shard_id)
        {
            try
            {
                Context.Connection.Execute("CALL fso_lot_top_100_calc_all(@date, @shard_id);", new { date = date, shard_id = shard_id });
                return true;
            }
            catch (Exception ex)
            {
                return false;
            }
        }

        /// <summary>
        /// Returns the top 100 lots for the given category and shard ID, including the lot name and location.
        /// </summary>
        /// <param name="shard_id">The shard ID for which to retrieve the top 100 lots.</param>
        /// <param name="category">The category for which to retrieve the top 100 lots.</param>
        public IEnumerable<DbLotTop100> GetByCategory(int shard_id, LotCategory category)
        {
            return Context.Connection.Query<DbLotTop100>("SELECT top.*, l.name as lot_name, l.location as lot_location FROM fso_lot_top_100 top LEFT JOIN fso_lots l ON top.lot_id = l.lot_id WHERE top.category = @category AND top.shard_id = @shard_id", new
            {
                category = category.ToString(),
                shard_id = shard_id
            });
        }

        /// <summary>
        /// Replaces the existing top 100 lot data with the given values.
        /// </summary>
        /// <param name="values">The values to replace the existing top 100 lot data.</param>
        public void Replace(IEnumerable<DbLotTop100> values)
        {
            try
            {
                var valuesConverted = values.Select(x =>
                {
                    return new
                    {
                        category = x.category.ToString(),
                        rank = x.rank,
                        shard_id = x.shard_id,
                        lot_id = x.lot_id,
                        minutes = x.minutes
                    };
                });

                Context.Connection.Execute("REPLACE INTO fso_lot_top_100 (category, rank, shard_id, lot_id, minutes) VALUES (@category, @rank, @shard_id, @lot_id, @minutes)", valuesConverted);
            }
            catch (Exception ex)
            {
            }
        }
    }
}
