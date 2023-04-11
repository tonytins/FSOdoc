using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FSO.UI
{
    /// <summary>
    /// Represents an interface for an FSO program.
    /// </summary>
    public interface IFSOProgram
    {
        /// <summary>
        /// Initializes the FSO program with the provided arguments.
        /// </summary>
        /// <param name="args">The arguments passed to the program.</param>
        /// <returns>True if initialization is successful, false otherwise.</returns>
        bool InitWithArguments(string[] args);

        /// <summary>
        /// Gets or sets a value indicating whether DirectX should be used in the FSO program.
        /// </summary>
        bool UseDX { get; set; }
    }
}
