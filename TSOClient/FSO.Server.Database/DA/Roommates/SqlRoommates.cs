using Dapper;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FSO.Server.Database.DA.Roommates
{
    public SqlRoommates(ISqlContext context) : base(context)
    {
    }

    /// <summary>
    /// Adds a new roommate to the database.
    /// </summary>
    /// <param name="roomie">The DbRoommate object containing the information of the new roommate.</param>
    /// <returns>True if the new roommate was successfully added, false otherwise.</returns>
    public bool Create(DbRoommate roomie)
    {
        try
        {
            return (uint)Context.Connection.Execute("INSERT INTO fso_roommates (avatar_id, lot_id, permissions_level, is_pending) " +
                            " VALUES (@avatar_id, @lot_id, @permissions_level, @is_pending);", roomie) > 0;
        }
        catch (SqlException)
        {
            return false;
        }
    }

    /// <summary>
    /// Retrieves information about a specific roommate from the database.
    /// </summary>
    /// <param name="avatar_id">The avatar ID of the roommate.</param>
    /// <param name="lot_id">The lot ID of the roommate.</param>
    /// <returns>A DbRoommate object containing the information of the roommate, or null if no such roommate exists.</returns>
    public DbRoommate Get(uint avatar_id, int lot_id)
    {
        return Context.Connection.Query<DbRoommate>("SELECT * FROM fso_roommates WHERE avatar_id = @avatar_id AND lot_id = @lot_id",
            new { avatar_id = avatar_id, lot_id = lot_id }).FirstOrDefault();
    }

    /// <summary>
    /// Retrieves a list of roommates for a specific avatar.
    /// </summary>
    /// <param name="avatar_id">The avatar ID of the owner of the roommates.</param>
    /// <returns>A list of DbRoommate objects containing the information of the roommates, or an empty list if there are no roommates.</returns>
    public List<DbRoommate> GetAvatarsLots(uint avatar_id)
    {
        return Context.Connection.Query<DbRoommate>("SELECT * FROM fso_roommates WHERE avatar_id = @avatar_id",
            new { avatar_id = avatar_id }).ToList();
    }

    /// <summary>
    /// Retrieves a list of roommates for a specific lot.
    /// </summary>
    /// <param name="lot_id">The lot ID of the lot.</param>
    /// <returns>A list of DbRoommate objects containing the information of the roommates, or an empty list if there are no roommates.</returns>
    public List<DbRoommate> GetLotRoommates(int lot_id)
    {
        return Context.Connection.Query<DbRoommate>("SELECT * FROM fso_roommates WHERE lot_id = @lot_id",
            new { lot_id = lot_id }).ToList();
    }

    /// <summary>
    /// Removes a roommate from a specified lot.
    /// </summary>
    /// <param name="avatar_id">The ID of the avatar to remove as a roommate.</param>
    /// <param name="lot_id">The ID of the lot from which to remove the avatar as a roommate.</param>
    /// <returns>The number of rows affected by the deletion.</returns>
    public uint RemoveRoommate(uint avatar_id, int lot_id)
    {
        return (uint)Context.Connection.Execute("DELETE FROM fso_roommates WHERE avatar_id = @avatar_id AND lot_id = @lot_id",
            new { avatar_id = avatar_id, lot_id = lot_id });
    }

    /// <summary>
    /// Declines a pending roommate request from a specified avatar for a specified lot.
    /// </summary>
    /// <param name="avatar_id">The ID of the avatar whose roommate request should be declined.</param>
    /// <param name="lot_id">The ID of the lot for which the roommate request should be declined.</param>
    /// <returns>True if the roommate request was declined; false otherwise.</returns>
    public bool DeclineRoommateRequest(uint avatar_id, int lot_id)
    {
        return Context.Connection.Execute("DELETE FROM fso_roommates WHERE avatar_id = @avatar_id AND lot_id = @lot_id AND is_pending = 1",
            new { avatar_id = avatar_id, lot_id = lot_id }) > 0;
    }

    /// <summary>
    /// Accepts a pending roommate request from a specified avatar for a specified lot.
    /// </summary>
    /// <param name="avatar_id">The ID of the avatar whose roommate request should be accepted.</param>
    /// <param name="lot_id">The ID of the lot for which the roommate request should be accepted.</param>
    /// <returns>True if the roommate request was accepted; false otherwise.</returns>
    public bool AcceptRoommateRequest(uint avatar_id, int lot_id)
    {
        return Context.Connection.Execute("UPDATE fso_roommates SET is_pending = 0 WHERE avatar_id = @avatar_id AND lot_id = @lot_id AND is_pending = 1",
            new { avatar_id = avatar_id, lot_id = lot_id }) > 0;
    }

    /// <summary>
    /// Updates the permissions level for a specified avatar as a roommate of a specified lot.
    /// </summary>
    /// <param name="avatar_id">The ID of the avatar whose permissions level should be updated.</param>
    /// <param name="lot_id">The ID of the lot for which the avatar's permissions level should be updated.</param>
    /// <param name="level">The new permissions level for the avatar.</param>
    /// <returns>True if the permissions level was updated; false otherwise.</returns>
    public bool UpdatePermissionsLevel(uint avatar_id, int lot_id, byte level)
    {
        return Context.Connection.Execute("UPDATE fso_roommates SET permissions_level = @level WHERE avatar_id = @avatar_id AND lot_id = @lot_id",
            new { level = level, avatar_id = avatar_id, lot_id = lot_id }) > 0;
    }
}
