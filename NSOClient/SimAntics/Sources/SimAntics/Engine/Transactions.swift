/// What a thread is waiting on from outside the lot (`VMThread.BlockingState`).
///
/// Only Transfer Funds waits so far. A primitive sets one and yields; the answer replaces it on a
/// later tick, and the primitive, running again, reads it.
public enum BlockingState: Sendable, Equatable {
    case transferFunds(TransferFundsState)

    /// Ticks spent waiting (`WaitTime`), counted by the thread.
    public var waitTime: Int {
        get { switch self { case .transferFunds(let state): state.waitTime } }
        set { switch self { case .transferFunds(var state): state.waitTime = newValue; self = .transferFunds(state) } }
    }
}

/// A transaction's answer (`VMTransferFundsState`).
public struct TransferFundsState: Sendable, Equatable {
    public var waitTime = 0
    public var responded = false
    public var success = false
    public var transferAmount: Int32 = 0
    public var firstPersistID: UInt32 = 0
    public var firstBudget: UInt32 = 0
    public var secondPersistID: UInt32 = 0
    public var secondBudget: UInt32 = 0

    public init(waitTime: Int = 0, responded: Bool = false, success: Bool = false, transferAmount: Int32 = 0,
                firstPersistID: UInt32 = 0, firstBudget: UInt32 = 0, secondPersistID: UInt32 = 0, secondBudget: UInt32 = 0) {
        self.waitTime = waitTime
        self.responded = responded
        self.success = success
        self.transferAmount = transferAmount
        self.firstPersistID = firstPersistID
        self.firstBudget = firstBudget
        self.secondPersistID = secondPersistID
        self.secondBudget = secondBudget
    }
}

/// The lot's money, as FreeSO's standalone global link (`VMTSOGlobalLinkStub`) keeps it: each
/// entity's budget, moved between entities by persist ID, with `maxisID` standing for the game.
///
/// This is a stand-in, matching FreeSO's stub so lots keep running. How NewSO's economy works is
/// deferred to the lot server.
extension VM {
    /// The persist ID that stands for the game itself ("Maxis"), which can always pay and be paid.
    public static let maxisID = UInt32.max

    /// The first entity, in object ID order, with a persist ID (`GetObjectByPersist`). Objects on a
    /// blueprint lot all have 0, so 0 finds the lowest-numbered object, as in FreeSO.
    public func entity(persistID: UInt32) -> Entity? {
        entities.first { $0.persistID == persistID }
    }

    /// Moves `amount` from one persist ID to another, or with `testOnly` only checks that it could
    /// (`VMTSOGlobalLinkStub.PerformTransaction`). It fails when either side isn't Maxis and has no
    /// entity, or when either budget would go below 0.
    public func performTransaction(testOnly: Bool, from source: UInt32, to target: UInt32, amount: Int32) -> Bool {
        let payer = entity(persistID: source), payee = entity(persistID: target)
        if (source != Self.maxisID && payer == nil) || (target != Self.maxisID && payee == nil) { return false }
        if let payer, !Self.canTransact(payer.budget, -Int64(amount)) { return false }
        if let payee, !Self.canTransact(payee.budget, Int64(amount)) { return false }
        if !testOnly {
            if let payer { payer.budget = UInt32(truncatingIfNeeded: Int64(payer.budget) - Int64(amount)) }
            if let payee { payee.budget = UInt32(truncatingIfNeeded: Int64(payee.budget) + Int64(amount)) }
        }
        return true
    }

    /// `VMBudget.CanTransact`: C# adds the `uint` budget and the `int` change as `long`s.
    private static func canTransact(_ budget: UInt32, _ change: Int64) -> Bool {
        Int64(budget) + change >= 0
    }

    /// Settles a transaction for a waiting thread and answers it on the next tick, as the stub
    /// does through `VMNetAsyncResponseCmd` (in `fso-oracle`, by the next tick every time).
    func requestTransaction(for objectID: Int16, testOnly: Bool, from source: UInt32, to target: UInt32, amount: Int32) {
        let success = performTransaction(testOnly: testOnly, from: source, to: target, amount: amount)
        let answer = TransferFundsState(responded: true, success: success, transferAmount: amount,
                                        firstPersistID: source, firstBudget: entity(persistID: source)?.budget ?? 0,
                                        secondPersistID: target, secondBudget: entity(persistID: target)?.budget ?? 0)
        queueAnswer(.transferFunds(answer), for: objectID)
    }
}
