using Dapper;
using FSO.Server.Database.DA.Utils;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FSO.Server.Database.DA.Tasks
{
    public class SqlTasks : AbstractSqlDA, ITasks
    {
        public SqlTasks(ISqlContext context) : base(context)
        {
        }

        /// <summary>
        /// Creates a new task in the database.
        /// </summary>
        /// <param name="task">The task to create</param>
        /// <returns>The ID of the newly created task</returns>
        public int Create(DbTask task)
        {
            return Context.Connection.Query<int>(
                "INSERT INTO fso_tasks (task_type, task_status, shard_id) " +
                "VALUES (@task_type, @task_status, @shard_id); SELECT LAST_INSERT_ID();", new
                {
                    task_type = task.task_type.ToString(),
                    task_status = task.task_status.ToString(),
                    shard_id = task.shard_id
                }).First();
        }

        /// <summary>
        /// Completes a task by updating its status and completion time in the database.
        /// </summary>
        /// <param name="task_id">The ID of the task to complete</param>
        /// <param name="status">The new status of the task</param>
        public void CompleteTask(int task_id, DbTaskStatus status)
        {
            Context.Connection.Execute("UPDATE fso_tasks set task_status = @task_status, time_completed = current_timestamp WHERE task_id = @task_id", new
            {
                task_id = task_id,
                task_status = status.ToString()
            });
        }

        /// <summary>
        /// Updates the status of a task in the database.
        /// </summary>
        /// <param name="task_id">The ID of the task to update</param>
        /// <param name="status">The new status of the task</param>
        public void SetStatus(int task_id, DbTaskStatus status)
        {
            Context.Connection.Execute("UPDATE fso_tasks set task_status = @task_status WHERE task_id = @task_id", new
            {
                task_id = task_id,
                task_status = status.ToString()
            });
        }

        /// <summary>
        /// Returns a paged list of all tasks in the database.
        /// </summary>
        /// <param name="offset">The number of items to skip before returning results</param>
        /// <param name="limit">The maximum number of items to return</param>
        /// <returns>A paged list of all tasks in the database</returns>
        public PagedList<DbTask> All(int offset = 1, int limit = 20)
        {
            var connection = Context.Connection;
            var total = connection.Query<int>("SELECT COUNT(*) FROM fso_tasks").FirstOrDefault();
            var results = connection.Query<DbTask>("SELECT t.*, s.name as shard_name FROM fso_tasks t LEFT JOIN fso_shards s ON s.shard_id = t.shard_id ORDER BY time_created DESC LIMIT @offset, @limit", new { offset = offset, limit = limit });
            return new PagedList<DbTask>(results, offset, total);
        }
    }
}
