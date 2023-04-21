using Dapper;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FSO.Server.Database.DA.Bookmarks
{
    /// <summary>
    /// Represents a class for managing bookmarks using SQL data access.
    /// </summary>
    public class SqlBookmarks : AbstractSqlDA, IBookmarks
    {
        public SqlBookmarks(ISqlContext context) : base(context)
        {
        }

        /// <summary>
        /// Creates a new bookmark in the database.
        /// </summary>
        /// <param name="bookmark">The bookmark to be created.</param>
        public void Create(DbBookmark bookmark)
        {
            Context.Connection.Execute("INSERT INTO fso_bookmarks (avatar_id, type, target_id) " +
                                        " VALUES (@avatar_id, @type, @target_id)"
                                        , bookmark);
        }

        /// <summary>
        /// Deletes a bookmark from the database.
        /// </summary>
        /// <param name="bookmark">The bookmark to be deleted.</param>
        /// <returns>True if the bookmark was deleted successfully, false otherwise.</returns>
        public bool Delete(DbBookmark bookmark)
        {
            return Context.Connection.Execute("DELETE FROM fso_bookmarks WHERE avatar_id = @avatar_id AND type = @type AND target_id = @target_id", bookmark) > 0;
        }

        /// <summary>
        /// Gets a list of bookmarks for the specified avatar.
        /// </summary>
        /// <param name="avatar_id">The ID of the avatar.</param>
        /// <returns>A list of bookmarks for the specified avatar.</returns>
        public List<DbBookmark> GetByAvatarId(uint avatar_id)
        {
            return Context.Connection.Query<DbBookmark>("SELECT * FROM fso_bookmarks WHERE avatar_id = @avatar_id", new { avatar_id = avatar_id }).ToList();
        }

        /// <summary>
        /// Gets a list of ignored avatars for the specified avatar.
        /// </summary>
        /// <param name="avatar_id">The ID of the avatar.</param>
        /// <returns>A list of ignored avatars for the specified avatar.</returns>
        public List<uint> GetAvatarIgnore(uint avatar_id)
        {
            return Context.Connection.Query<uint>("SELECT target_id FROM fso_bookmarks WHERE avatar_id = @avatar_id AND type = 5", new { avatar_id = avatar_id }).ToList();
        }
    }
}
