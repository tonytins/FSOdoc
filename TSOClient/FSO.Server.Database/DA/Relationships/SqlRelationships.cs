using Dapper;
using FSO.Server.Common;
using MySql.Data.MySqlClient;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FSO.Server.Database.DA.Relationships
{
    /// <summary>
    /// SqlRelationships is a class that implements the IRelationships interface
    /// to provide data access operations for the fso_relationships table.
    /// </summary>
    public class SqlRelationships : AbstractSqlDA, IRelationships
    {

        /// <summary>
        /// Constructs a new instance of SqlRelationships with the specified ISqlContext object.
        /// </summary>
        /// <param name="context">The ISqlContext object representing the database connection.</param>
        public SqlRelationships(ISqlContext context) : base(context)
        {

        }

        /// <summary>
        /// Deletes all relationships involving the specified entity from the fso_relationships table.
        /// </summary>
        /// <param name="entity_id">The ID of the entity whose relationships will be deleted.</param>
        /// <returns>The number of rows affected by the DELETE operation.</returns>
        public int Delete(uint entity_id)
        {
            return Context.Connection.ExecuteScalar<int>(
                "DELETE FROM fso_relationships WHERE from_id = @entity_id OR to_id = @entity_id",
                new { entity_id = entity_id }
            );
        }

        /// <summary>
        /// Returns a list of all bidirectional relationships involving the specified entity
        /// from the fso_relationships table.
        /// </summary>
        /// <param name="entity_id">The ID of the entity whose bidirectional relationships will be retrieved.</param>
        /// <returns>A list of DbRelationship objects representing the bidirectional relationships involving the specified entity.</returns>
        public List<DbRelationship> GetBidirectional(uint entity_id)
        {
            return Context.Connection.Query<DbRelationship>(
                "SELECT * FROM fso_relationships WHERE (from_id = @entity_id AND to_id < 16777216) OR (to_id = @entity_id AND from_id < 16777216)",
                new { entity_id = entity_id }
            ).ToList();
        }

        /// <summary>
        /// Returns a list of all outgoing relationships involving the specified entity
        /// from the fso_relationships table.
        /// </summary>
        /// <param name="entity_id">The ID of the entity whose outgoing relationships will be retrieved.</param>
        /// <returns>A list of DbRelationship objects representing the outgoing relationships involving the specified entity.</returns>
        public List<DbRelationship> GetOutgoing(uint entity_id)
        {
            return Context.Connection.Query<DbRelationship>(
                "SELECT * FROM fso_relationships WHERE from_id = @entity_id",
                new { entity_id = entity_id }
            ).ToList();
        }

        /// <summary>
        /// Inserts or updates multiple DbRelationship objects in the fso_relationships table.
        /// </summary>
        /// <param name="entries">A list of DbRelationship objects to insert or update.</param>
        /// <returns>The number of rows affected by the INSERT or UPDATE operation.</returns>

        public int UpdateMany(List<DbRelationship> entries)
        {
            var date = Epoch.Now;
            var conn = (MySqlConnection)Context.Connection;
            int rows;
            using (MySqlCommand cmd = new MySqlCommand("", conn))
            {
                try
                {
                    StringBuilder sCommand = new StringBuilder("INSERT INTO fso_relationships (from_id, to_id, value, `index`, `date`) VALUES ");

                    bool first = true;
                    foreach (var item in entries)
                    {
                        if (!first) sCommand.Append(",");
                        first = false;
                        sCommand.Append("(");
                        sCommand.Append(item.from_id);
                        sCommand.Append(",");
                        sCommand.Append(item.to_id);
                        sCommand.Append(",");
                        sCommand.Append(item.value);
                        sCommand.Append(",");
                        sCommand.Append(item.index);
                        sCommand.Append(",");
                        sCommand.Append(date);
                        sCommand.Append(")");
                    }
                    sCommand.Append(" ON DUPLICATE KEY UPDATE value = VALUES(`value`); ");

                    cmd.CommandTimeout = 300;
                    cmd.CommandText = sCommand.ToString();
                    rows = cmd.ExecuteNonQuery();
                }
                catch (Exception e)
                {
                    return -1;
                }
                return rows;
            }
        }
    }
}
