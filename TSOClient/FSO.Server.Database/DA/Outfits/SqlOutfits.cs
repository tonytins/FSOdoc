using Dapper;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FSO.Server.Database.DA.Outfits
{
    public class SqlOutfits : AbstractSqlDA, IOutfits
    {
        /// <summary>
        /// Creates a new outfit in the database with the given information.
        /// </summary>
        /// <param name="outfit">The outfit to create.</param>
        /// <returns>The ID of the newly created outfit.</returns>
        public uint Create(DbOutfit outfit)
        {
            try
            {
                // Execute an SQL INSERT statement to create the new outfit, passing in the outfit's properties as parameters
                // The SELECT statement at the end returns the ID of the newly created outfit
                return (uint)Context.Connection.Query<int>("INSERT INTO fso_outfits (avatar_owner, object_owner, asset_id, sale_price, purchase_price, outfit_type, outfit_source) " +
                                            " VALUES (@avatar_owner, @object_owner, @asset_id, @sale_price, @purchase_price, @outfit_type, @outfit_source); " +
                                            " SELECT LAST_INSERT_ID();"
                                            , new
                                            {
                                                avatar_owner = outfit.avatar_owner,
                                                object_owner = outfit.object_owner,
                                                asset_id = outfit.asset_id,
                                                sale_price = outfit.sale_price,
                                                purchase_price = outfit.purchase_price,
                                                outfit_type = outfit.outfit_type,
                                                outfit_source = outfit.outfit_source.ToString()
                                            }).First();
            }
            catch (Exception ex)
            {
                // If there was an exception while creating the outfit, return the maximum possible value for an unsigned integer to indicate failure
                return uint.MaxValue;
            }
        }

        /// <summary>
        /// Changes the owner of an outfit in the database.
        /// </summary>
        /// <param name="outfit_id">The ID of the outfit to change the owner of.</param>
        /// <param name="object_owner">The ID of the object owner of the outfit (can be null).</param>
        /// <param name="new_avatar_owner">The ID of the new avatar owner of the outfit.</param>
        /// <returns>True if the owner was successfully changed, false otherwise.</returns>
        public bool ChangeOwner(uint outfit_id, uint object_owner, uint new_avatar_owner)
        {
            // Execute an SQL UPDATE statement to change the avatar owner of the outfit with the given ID and object owner,
            // passing in the new avatar owner as a parameter
            // If the update affects any rows, return true; otherwise, return false
            return Context.Connection.Execute("UPDATE fso_outfits SET avatar_owner = @avatar_owner, object_owner = NULL WHERE outfit_id = @outfit_id and object_owner = @object_owner", new { outfit_id = outfit_id, object_owner = object_owner, avatar_owner = new_avatar_owner }) > 0;
        }

        /// <summary>
        /// Updates the sale price of an outfit in the database.
        /// </summary>
        /// <param name="outfit_id">The ID of the outfit to update the sale price of.</param>
        /// <param name="object_owner">The ID of the object owner of the outfit (can be null).</param>
        /// <param name="new_price">The new sale price of the outfit.</param>
        /// <returns>True if the sale price was successfully updated, false otherwise.</returns>

        public bool UpdatePrice(uint outfit_id, uint object_owner, int new_price)
        {
            return Context.Connection.Execute("UPDATE fso_outfits SET sale_price = @sale_price WHERE outfit_id = @outfit_id AND object_owner = @object_owner", new { outfit_id = outfit_id, object_owner = object_owner, sale_price = new_price }) > 0;
        }

        /// <summary>
        /// Deletes the outfit with the specified ID from the object with the specified ID.
        /// </summary>
        /// <param name="outfit_id">The ID of the outfit to delete.</param>
        /// <param name="object_id">The ID of the object that owns the outfit.</param>
        /// <returns>True if the outfit was successfully deleted; otherwise, false.</returns>
        public bool DeleteFromObject(uint outfit_id, uint object_id)
        {
            return Context.Connection.Execute("DELETE FROM fso_outfits WHERE outfit_id = @outfit_id AND object_owner = @object_owner", new { outfit_id = outfit_id, object_owner = object_id }) > 0;
        }

        /// <summary>
        /// Deletes the outfit with the specified ID from the avatar with the specified ID.
        /// </summary>
        /// <param name="outfit_id">The ID of the outfit to delete.</param>
        /// <param name="avatar_id">The ID of the avatar that owns the outfit.</param>
        /// <returns>True if the outfit was successfully deleted; otherwise, false.</returns>
        public bool DeleteFromAvatar(uint outfit_id, uint avatar_id)
        {
            return Context.Connection.Execute("DELETE FROM fso_outfits WHERE outfit_id = @outfit_id AND avatar_owner = @avatar_owner", new { outfit_id = outfit_id, avatar_owner = avatar_id }) > 0;
        }

        /// <summary>
        /// Returns a list of outfits owned by the avatar with the specified ID.
        /// </summary>
        /// <param name="avatar_id">The ID of the avatar whose outfits are being retrieved.</param>
        /// <returns>A list of outfits owned by the specified avatar.</returns>
        public List<DbOutfit> GetByAvatarId(uint avatar_id)
        {
            return Context.Connection.Query<DbOutfit>("SELECT * FROM fso_outfits WHERE avatar_owner = @avatar_id", new { avatar_id = avatar_id }).ToList();
        }

        /// <summary>
        /// Returns a list of outfits owned by the object with the specified ID.
        /// </summary>
        /// <param name="object_id">The ID of the object whose outfits are being retrieved.</param>
        /// <returns>A list of outfits owned by the specified object.</returns>
        public List<DbOutfit> GetByObjectId(uint object_id)
        {
            return Context.Connection.Query<DbOutfit>("SELECT * FROM fso_outfits WHERE object_owner = @object_id", new { object_id = object_id }).ToList();
        }
    }
}
