using FSO.SimAntics.Engine;
using FSO.SimAntics.Engine.Utils;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FSO.SimAntics.Primitives
{
    /// <summary>
    /// Represents a primitive handler for the VM transfer funds operation in TS1.
    /// </summary>
    /// <remarks>
    /// This primitive handler is used to deduct funds from the budget of a family in The Sims 1 (TS1) game,
    /// but with limited functionality compared to the original "transfer funds" operation. Only deductions
    /// from Maxis are supported, and instead of subtracting, the operation actually adds the amount to the budget.
    /// </remarks>
    public class VMTS1Budget : VMPrimitiveHandler
    {
        /// <summary>
        /// Executes the VM transfer funds operation.
        /// </summary>
        /// <param name="context">The VM stack frame context.</param>
        /// <param name="args">The operand containing the amount to transfer and other flags.</param>
        /// <returns>The exit code indicating the result of the operation.</returns>
        public override VMPrimitiveExitCode Execute(VMStackFrame context, VMPrimitiveOperand args)
        {
            var operand = (VMTransferFundsOperand)args;
            var amount = VMMemory.GetBigVariable(context, operand.GetAmountOwner(), (short)operand.AmountData);

            if ((operand.Flags & VMTransferFundsFlags.Subtract) > 0)
            {
                // Instead of subtracting, we're adding, because TS1 has inverted flags.
                amount = -amount;
            }

            var oldBudget = context.VM.CurrentFamily?.Budget ?? 0;
            var newBudget = oldBudget - amount;

            if (oldBudget < 0)
            {
                // If the old budget is negative, return false.
                return VMPrimitiveExitCode.GOTO_FALSE;
            }

            if ((operand.Flags & VMTransferFundsFlags.JustTest) == 0 && context.VM.CurrentFamily != null)
            {
                // If the JustTest flag is not set, update the budget of the current family.
                context.VM.CurrentFamily.Budget = newBudget;
            }

            // Return true.
            return VMPrimitiveExitCode.GOTO_TRUE;

            // Note: TS1 does have expense types, which could be used for expenses monitoring,
            // but it is not supported in this implementation.
        }
    }
}

