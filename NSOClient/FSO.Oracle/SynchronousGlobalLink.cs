/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
 * If a copy of the MPL was not distributed with this file, You can obtain one at
 * http://mozilla.org/MPL/2.0/.
 */

using FSO.SimAntics;
using FSO.SimAntics.Engine.TSOTransaction;

namespace FSO.Oracle
{
    /// <summary>
    /// FreeSO's standalone global link, with transactions answered at once instead of from a
    /// background thread.
    /// </summary>
    /// <remarks>
    /// <c>VMTSOGlobalLinkStub.PerformTransaction</c> settles the transaction, then calls back on a new
    /// <c>System.Threading.Thread</c>, whose answer (a <c>VMNetAsyncResponseCmd</c>) reaches the lot on
    /// whichever tick the thread happens to finish before. Calling back on the calling thread makes
    /// it always the next tick, which is what the background thread almost always did. Everything
    /// else is the stub's: this re-implements only that interface method, and stays a
    /// <c>VMTSOGlobalLinkStub</c>, which the response command checks for.
    /// </remarks>
    public sealed class SynchronousGlobalLink : VMTSOGlobalLinkStub, IVMTSOGlobalLink
    {
        public new void PerformTransaction(VM vm, bool testOnly, uint uid1, uint uid2, int amount, VMAsyncTransactionCallback callback)
        {
            var result = PerformTransaction(vm, testOnly, uid1, uid2, amount);
            if (callback == null) return;
            var obj1 = vm.GetObjectByPersist(uid1);
            var obj2 = vm.GetObjectByPersist(uid2);
            callback(result, amount,
                uid1, (obj1 == null) ? 0 : obj1.TSOState.Budget.Value,
                uid2, (obj2 == null) ? 0 : obj2.TSOState.Budget.Value);
        }
    }
}
