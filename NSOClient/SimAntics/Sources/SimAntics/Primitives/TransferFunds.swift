extension Primitives {
    /// Moves money between the caller, the stack object, owners, and the game (opcode 25).
    ///
    /// Ports FreeSO's `VMTransferFunds` against its standalone global link (see
    /// ``VM/performTransaction(testOnly:from:to:amount:)``). The amount is a 32-bit variable. Each
    /// transfer type names a payer and a payee by persist ID, or Maxis; old types do nothing and are
    /// true. In a check tree a transaction can only be tested, at once: true if it could happen, and
    /// a real one is false. Otherwise the thread waits a tick for the answer, then puts the amount
    /// in `TempXL` 0 and is true if it went through. "Put stack object's cash into TempXL 0" reads
    /// the stack object's budget instead. A stack object the type needs and doesn't have fails, as
    /// FreeSO's null reference does.
    ///
    /// On a blueprint lot every object's persist ID is 0, which FreeSO resolves to the
    /// lowest-numbered object, so "me" and "the stack object" pay from, and are paid into, its budget.
    public enum TransferFunds: Primitive {
        public static let name = "transfer_funds"
        public static let opcode: UInt8 = 25

        /// Who pays whom (`VMTransferFundsType`).
        public enum TransferType: UInt8, Sendable {
            case deprecatedAdd = 0, deprecatedSubtract, meToMaxis, deprecatedMeToStackObject
            case deprecatedMeToStackObjectsOwner, maxisToMe, maxisToStackObjectsOwner, stackObjectsOwnerToMaxis
            case deprecatedOwnerOfTemp0ToOwnerOfTemp1, fromMeToStackObject, fromStackObjectToMe
            case fromMaxisToStackObject, fromStackObjectToMaxis, fromStackObjectToStackObjectOwner
            case deprecatedFromOwnerOfObjectToObject, deprecatedFromTemp0ToOwnerOfTemp1
            case deprecatedFromOwnerOfTemp0ToTemp1, putStackObjectCashIntoTempXL0, fromStackObjectToLotRoommates
            case fromLotOwnerToMaxis, fromMaxisToLotOwner, unknown, characterToSharedAccount
            case sharedAccountToCharacter, meToLotRoommates
        }

        public struct Operand: PrimitiveOperand, Equatable {
            /// Where the amount's scope comes from, in older behavior: 0 literal, 1 parameters,
            /// 2 locals, and 3 (or anything else) `amountScope`.
            public var oldAmountOwner: UInt8
            public var amountScope: UInt8
            public var amountData: UInt16
            /// Bit 0: only test the transaction.
            public var flags: UInt8
            public var unused: UInt8
            /// What the money is for (`VMTransferFundsExpenseType`); FreeSO scales none of them.
            public var expenseType: UInt8
            public var transferType: UInt8

            public init(oldAmountOwner: UInt8 = 3, amountScope: UInt8, amountData: UInt16, flags: UInt8 = 0, unused: UInt8 = 0,
                        expenseType: UInt8 = 0, transferType: UInt8) {
                self.oldAmountOwner = oldAmountOwner
                self.amountScope = amountScope
                self.amountData = amountData
                self.flags = flags
                self.unused = unused
                self.expenseType = expenseType
                self.transferType = transferType
            }

            public init(bytes: [UInt8]) {
                var reader = OperandReader(bytes)
                oldAmountOwner = reader.uint8()
                amountScope = reader.uint8()
                amountData = reader.uint16()
                flags = reader.uint8()
                unused = reader.uint8()
                expenseType = reader.uint8()
                transferType = reader.uint8()
            }

            public func encoded() -> [UInt8] {
                OperandWriter.bytes { writer in
                    writer.uint8(oldAmountOwner)
                    writer.uint8(amountScope)
                    writer.uint16(amountData)
                    writer.uint8(flags)
                    writer.uint8(unused)
                    writer.uint8(expenseType)
                    writer.uint8(transferType)
                }
            }

            public var justTest: Bool { flags & 1 != 0 }

            /// The amount's variable (`GetAmountOwner`).
            var amount: Variable {
                let scope: UInt16 = switch oldAmountOwner {
                case 0: UInt16(VariableScope.literal.rawValue)
                case 1: UInt16(VariableScope.parameters.rawValue)
                case 2: UInt16(VariableScope.local.rawValue)
                default: UInt16(amountScope)
                }
                return Variable(rawScope: scope, data: Int16(bitPattern: amountData))
            }
        }

        public static func execute(_ operand: Operand, in frame: StackFrame) throws(SimAnticsError) -> ExitCode {
            let thread = frame.thread
            let type = TransferType(rawValue: operand.transferType)
            // Waiting on an answer from an earlier run of this instruction?
            if case .transferFunds(let state) = thread.blockingState {
                guard state.responded else { return .continueNextTick }
                thread.blockingState = nil
                if type == .putStackObjectCashIntoTempXL0 {
                    thread.tempXL[0] = Int32(bitPattern: state.firstBudget)
                    return .gotoTrue
                }
                thread.tempXL[0] = state.transferAmount
                return state.success ? .gotoTrue : .gotoFalse
            }

            var amount = try frame.bigValue(of: operand.amount)
            let maxis = VM.maxisID
            var source = maxis, target = maxis
            func stackObject() throws(SimAnticsError) -> Entity {
                guard let entity = frame.stackObject else { throw .nullReference("Transfer Funds with no stack object") }
                return entity
            }
            func caller() throws(SimAnticsError) -> Entity {
                guard let entity = frame.caller else { throw .nullReference("Transfer Funds with no caller") }
                return entity
            }
            switch type {
            case .meToMaxis: source = try caller().persistID
            case .maxisToMe: target = try caller().persistID
            case .maxisToStackObjectsOwner: if let owner = frame.stackObject?.ownerID { target = owner }
            case .stackObjectsOwnerToMaxis: if let owner = frame.stackObject?.ownerID { source = owner }
            case .fromMeToStackObject: source = try caller().persistID; target = try stackObject().persistID
            case .fromStackObjectToMe: source = try stackObject().persistID; target = try caller().persistID
            case .fromMaxisToStackObject: target = try stackObject().persistID
            case .fromStackObjectToMaxis: source = try stackObject().persistID
            case .fromStackObjectToStackObjectOwner, .fromStackObjectToLotRoommates:
                source = try stackObject().persistID
                target = try stackObject().ownerID
            case .putStackObjectCashIntoTempXL0: source = try stackObject().persistID; amount = 0
            case .fromLotOwnerToMaxis: source = frame.vm.lotOwnerID
            case .fromMaxisToLotOwner: target = frame.vm.lotOwnerID
            case .meToLotRoommates: if let owner = frame.stackObject?.ownerID { target = owner }  // the object's owner, for doors
            default: return .gotoTrue
            }

            // In a check tree, transactions are instant and can only be tested.
            if thread.isCheck {
                if type == .putStackObjectCashIntoTempXL0 {
                    thread.tempXL[0] = Int32(bitPattern: try stackObject().budget)
                    return .gotoTrue
                }
                guard operand.justTest else { return .gotoFalse }
                thread.tempXL[0] = amount
                return frame.vm.performTransaction(testOnly: true, from: source, to: target, amount: amount) ? .gotoTrue : .gotoFalse
            }
            thread.blockingState = .transferFunds(TransferFundsState())
            frame.vm.requestTransaction(for: try caller().objectID, testOnly: operand.justTest, from: source, to: target, amount: amount)
            return .continueNextTick
        }
    }
}
