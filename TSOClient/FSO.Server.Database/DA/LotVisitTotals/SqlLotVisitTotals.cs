using Dapper;
using FSO.Server.Database.DA.Utils;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FSO.Server.Database.DA.LotVisitTotals
{
    /// <summary>
    /// Data access object for managing lot visit totals in the database.
    /// </summary>
    public class SqlLotVisitTotals : AbstractSqlDA, ILotVisitTotals
    {
        public SqlLotVisitTotals(ISqlContext context) : base(context)
        {
        }

        /// <summary>
        /// Inserts or updates a collection of lot visit totals in the database.
        /// </summary>
        /// <param name="input">The collection of lot visit totals to insert or update.</param>
        public void Insert(IEnumerable<DbLotVisitTotal> input)
        {
            try
            {
                // Executes a buffered insert query to efficiently insert or update the visit totals.
                Context.Connection.ExecuteBufferedInsert("INSERT INTO fso_lot_visit_totals (lot_id, date, minutes) VALUES (@lot_id, @date, @minutes) ON DUPLICATE KEY UPDATE minutes=VALUES(minutes)", input, 100);
            }
            catch (Exception ex)
            {
                // TODO: Handle the exception.
            }
        }

        /// <summary>
        /// Deletes lot visit totals from the database that are older than the specified date.
        /// </summary>
        /// <param name="date">The date before which to delete lot visit totals.</param>
        public void Purge(DateTime date)
        {
            // Executes a delete query to remove visit totals that are older than the specified date.
            Context.Connection.Execute("DELETE FROM fso_lot_visit_totals WHERE date < @date", new { date = date });
        }
    }
}
