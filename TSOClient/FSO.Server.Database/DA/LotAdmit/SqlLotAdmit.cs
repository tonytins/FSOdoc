using Dapper;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FSO.Server.Database.DA.LotAdmit
{
    public class SqlLotAdmit : AbstractSqlDA, ILotAdmit
    {
        public SqlLotAdmit(ISqlContext context) : base(context)
        {
        }

        /// <summary>
        /// Inserts a new lot admission record into the fso_lot_admit table.
        /// </summary>
        /// <param name="admission">The lot admission record to create.</param>
        public void Create(DbLotAdmit admission)
        {
            Context.Connection.Execute("INSERT INTO fso_lot_admit (lot_id, avatar_id, admit_type) " +
                                        " VALUES (@lot_id, @avatar_id, @admit_type)"
                                        , admission);
        }

        /// <summary>
        /// Deletes a lot admission record from the fso_lot_admit table.
        /// </summary>
        /// <param name="admission">The lot admission record to delete.</param>
        /// <returns>Returns true if the record was deleted, false otherwise.</returns>
        public bool Delete(DbLotAdmit admission)
        {
            return Context.Connection.Execute("DELETE FROM fso_lot_admit WHERE lot_id = @lot_id AND admit_type = @admit_type AND avatar_id = @avatar_id", admission) > 0;
        }

        /// <summary>
        /// Retrieves all lot admission records for the given lot ID from the fso_lot_admit table.
        /// </summary>
        /// <param name="lot_id">The ID of the lot to retrieve admission records for.</param>
        /// <returns>A list of lot admission records for the given lot ID.</returns>
        public List<DbLotAdmit> GetLotInfo(int lot_id)
        {
            return Context.Connection.Query<DbLotAdmit>("SELECT * FROM fso_lot_admit WHERE lot_id = @lot_id", new { lot_id = lot_id }).ToList();
        }

        /// <summary>
        /// Retrieves a list of avatars who were denied admission to the given lot for the given admit type.
        /// </summary>
        /// <param name="lot_id">The ID of the lot to retrieve admission records for.</param>
        /// <param name="admit_type">The type of admission to retrieve (1 = invite, 2 = visitor).</param>
        /// <returns>A list of avatar IDs who were denied admission to the given lot.</returns>
        public List<uint> GetLotAdmitDeny(int lot_id, byte admit_type)
        {
            return Context.Connection.Query<uint>("SELECT avatar_id FROM fso_lot_admit WHERE lot_id = @lot_id AND admit_type = @admit_type", new { lot_id = lot_id, admit_type = admit_type }).ToList();
        }
    }
}
