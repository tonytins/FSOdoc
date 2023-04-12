/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
 * If a copy of the MPL was not distributed with this file, You can obtain one at
 * http://mozilla.org/MPL/2.0/. 
 */

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using FSO.SimAntics.Engine;
using FSO.Files.Utils;

namespace FSO.SimAntics.Primitives
{
    /// <summary>
    /// Represents a primitive handler for testing if the caller's active interaction is with a stack object.
    /// </summary>
    public class VMTestSimInteractingWith : VMPrimitiveHandler
    {
        /// <summary>
        /// Executes the VM primitive to test if the caller's active interaction is with a stack object.
        /// </summary>
        /// <param name="context">The VM stack frame context.</param>
        /// <param name="args">The operand containing the required data for the operation (not used in this case).</param>
        /// <returns>The exit code indicating the result of the operation.</returns>
        public override VMPrimitiveExitCode Execute(VMStackFrame context, VMPrimitiveOperand args)
        {
            // If the caller's active interaction is with the stack object, return true, else return false.
            var callerActive = context.Caller.Thread.Stack.LastOrDefault();
            return (callerActive != null && callerActive.ActionTree && context.Caller.Thread.Queue[0].Callee == context.StackObject)
                ? VMPrimitiveExitCode.GOTO_TRUE : VMPrimitiveExitCode.GOTO_FALSE;
        }
    }

    /// <summary>
    /// Represents an operand for the VMTestSimInteractingWith primitive, but does not contain any data.
    /// </summary>
    public class VMTestSimInteractingWithOperand : VMPrimitiveOperand
    {
        #region VMPrimitiveOperand Members
        /// <summary>
        /// Reads the operand data from a byte array, but does nothing, as this operand has no data.
        /// </summary>
        /// <param name="bytes">The byte array containing the operand data.</param>
        public void Read(byte[] bytes)
        {
            // Nothing to read, as this operand has no data.
        }

        /// <summary>
        /// Writes the operand data to a byte array, but does nothing, as this operand has no data.
        /// </summary>
        /// <param name="bytes">The byte array to write the operand data to.</param>
        public void Write(byte[] bytes)
        {
            // Nothing to write, as this operand has no data.
        }
        #endregion
    }
}
