using Dapper;
using MySql.Data.MySqlClient;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FSO.Server.Database.DA.AvatarClaims
{
    public class SqlAvatarClaims : AbstractSqlDA, IAvatarClaims
    {
        public SqlAvatarClaims(ISqlContext context) : base(context)
        {
        }

        /// <summary>
        /// Claims ownership of an avatar for a new owner.
        /// </summary>
        /// <param name="id">The ID of the avatar claim to update.</param>
        /// <param name="previousOwner">The previous owner of the avatar.</param>
        /// <param name="newOwner">The new owner of the avatar.</param>
        /// <param name="location">The location of the avatar.</param>
        /// <returns>True if the claim was updated successfully, false otherwise.</returns>
        public bool Claim(int id, string previousOwner, string newOwner, uint location)
        {
            try
            {
                Context.Connection.Query("UPDATE fso_avatar_claims SET owner = @owner, location = @location WHERE avatar_claim_id = @claim_id AND owner = @previous_owner", new { claim_id = (int)id, previous_owner = previousOwner, owner = newOwner, location = location });
                var newClaim = Context.Connection.Query<DbAvatarClaim>("SELECT * FROM fso_avatar_claims WHERE avatar_claim_id = @claim_id AND owner = @owner", new { claim_id = (int)id, owner = newOwner }).FirstOrDefault();
                return newClaim != null;
            }
            catch (MySqlException ex)
            {
                return false;
            }
        }

        /// <summary>
        /// Removes all remaining claims for an owner at a specific location.
        /// </summary>
        /// <param name="previousOwner">The previous owner of the avatar.</param>
        /// <param name="location">The location of the avatar.</param>
        public void RemoveRemaining(string previousOwner, uint location)
        {
            Context.Connection.Query("DELETE FROM fso_avatar_claims WHERE location = @location AND owner = @previous_owner", new { previous_owner = previousOwner, location = location });
        }

        /// <summary>
        /// Deletes a specific avatar claim.
        /// </summary>
        /// <param name="id">The ID of the avatar claim to delete.</param>
        /// <param name="owner">The owner of the avatar claim.</param>
        public void Delete(int id, string owner)
        {
            Context.Connection.Query("DELETE FROM fso_avatar_claims WHERE owner = @owner AND avatar_claim_id = @claim_id", new { owner = owner, claim_id = (int)id });
        }

        /// <summary>
        /// Deletes all avatar claims for a specific owner.
        /// </summary>
        /// <param name="owner">The owner of the avatar claims to delete.</param>
        public void DeleteAll(string owner)
        {
            Context.Connection.Query("DELETE FROM fso_avatar_claims WHERE owner = @owner", new { owner = owner });
        }

        /// <summary>
        /// Gets a specific avatar claim by ID.
        /// </summary>
        /// <param name="id">The ID of the avatar claim to retrieve.</param>
        /// <returns>The avatar claim with the specified ID, or null if not found.</returns>
        public DbAvatarClaim Get(int id)
        {
            return Context.Connection.Query<DbAvatarClaim>("SELECT * FROM fso_avatar_claims WHERE avatar_claim_id = @claim_id", new { claim_id = (int)id }).FirstOrDefault();
        }

        /// <summary>
        /// Retrieves all avatar claims associated with a specific owner.
        /// </summary>
        /// <param name="owner">The name of the owner to retrieve the avatar claims for.</param>
        /// <returns>An enumerable collection of all avatar claims associated with the specified owner.</returns>
        public IEnumerable<DbAvatarClaim> GetAllByOwner(string owner)
        {
            return Context.Connection.Query<DbAvatarClaim>("SELECT * FROM fso_avatar_claims WHERE owner = @owner", new { owner = owner });
        }

        /// <summary>
        /// Attempts to create a new avatar claim.
        /// </summary>
        /// <param name="claim">The avatar claim to create.</param>
        /// <returns>The ID of the newly created avatar claim, or null if the creation failed.</returns>
        public int? TryCreate(DbAvatarClaim claim)
        {
            try
            {
                return Context.Connection.Query<int>("INSERT INTO fso_avatar_claims (avatar_id, owner, location) " +
                    " VALUES (@avatar_id, @owner, @location); SELECT LAST_INSERT_ID();", claim).First();
            }
            catch (MySqlException ex)
            {
                return null;
            }
        }
    }
}
