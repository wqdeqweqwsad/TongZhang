import XCTest
@testable import TongZhang

final class SettlementEngineTests: XCTestCase {
    @MainActor
    func testInvalidProfileSnapshotsArePreservedAndLocked() throws {
        let suiteName = "TongZhangTests.invalidProfile.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let key = "tongzhang.ledger.snapshot.v2"
        let source = LedgerStore(defaults: defaults)
        XCTAssertTrue(source.updateNames(ming: "阿青", hong: "阿禾"))
        let original = try XCTUnwrap(defaults.data(forKey: key))
        let fields: [(String, Any)] = [
            ("mingName", "   "),
            ("hongName", String(repeating: "长", count: 17)),
            ("mingAvatar", Data(repeating: 1, count: 300_001).base64EncodedString()),
            ("hongAvatar", ""),
            ("partnerInviteCode", "123456\n"),
            ("isPartnerBound", true)
        ]
        for (field, value) in fields {
            var object = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [String: Any])
            object[field] = value
            let invalidData = try JSONSerialization.data(withJSONObject: object)
            defaults.set(invalidData, forKey: key)
            let restored = LedgerStore(defaults: defaults)
            XCTAssertFalse(restored.canEdit, field)
            XCTAssertFalse(restored.updateNames(ming: "新昵称", hong: "阿禾"), field)
            XCTAssertEqual(defaults.data(forKey: key), invalidData, field)
        }
    }

    @MainActor
    func testInvalidDatesAreRejectedWithoutMutation() {
        let store = LedgerStore(persistenceEnabled: false)
        for interval in [Double.infinity, -Double.infinity, Double.nan, Date.distantFuture.timeIntervalSinceReferenceDate + 1] {
            let expense = Expense(title: "无效日期", amountInCents: 100, paidBy: .ming,
                                  category: .food, date: Date(timeIntervalSinceReferenceDate: interval))
            XCTAssertFalse(store.add(expense))
        }
        XCTAssertTrue(store.expenses.isEmpty)
    }

    @MainActor
    func testSettlementConfirmationRejectsChangedBalance() {
        let store = LedgerStore(persistenceEnabled: false)
        XCTAssertFalse(store.isPartnerBound)
        store.add(Expense(title: "晚餐", amountInCents: 10000, paidBy: .ming, category: .food))
        let confirmed = store.currentBalance
        store.add(Expense(title: "车费", amountInCents: 2000, paidBy: .hong, category: .transport))
        store.settle(expectedBalance: confirmed)
        XCTAssertTrue(store.settlements.isEmpty)
        XCTAssertEqual(store.currentBalance.amountInCents, 4000)
        XCTAssertNotNil(store.saveError)
        store.settle(expectedBalance: store.currentBalance)
        XCTAssertEqual(store.settlements.count, 1)
        XCTAssertTrue(store.isSettled)
    }

    @MainActor
    func testAvatarDataPersistsAndCanBeRemoved() {
        let suiteName = "TongZhangTests.avatars.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = LedgerStore(defaults: defaults)
        let bytes = Data([1, 2, 3])
        XCTAssertTrue(store.updateAvatar(bytes, for: .ming))
        XCTAssertFalse(store.updateAvatar(Data(), for: .hong))
        XCTAssertFalse(store.updateAvatar(Data(repeating: 0, count: 300_001), for: .ming))
        let restored = LedgerStore(defaults: defaults)
        XCTAssertEqual(restored.avatar(for: .ming), bytes)
        XCTAssertNil(restored.avatar(for: .hong))
        XCTAssertTrue(restored.updateAvatar(nil, for: .ming))
        XCTAssertNil(LedgerStore(defaults: defaults).avatar(for: .ming))
    }

    @MainActor
    func testNamesPersistWithoutChangingAccountingIdentity() {
        let suiteName = "TongZhangTests.names.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = LedgerStore(defaults: defaults)
        store.add(Expense(title: "晚餐", amountInCents: 10000, paidBy: .ming, category: .food))
        let balance = store.currentBalance
        XCTAssertTrue(store.updateNames(ming: " 阿青 ", hong: "阿禾"))
        XCTAssertFalse(store.updateNames(ming: " ", hong: "阿禾"))
        XCTAssertFalse(store.updateNames(ming: String(repeating: "长", count: 17), hong: "阿禾"))
        let restored = LedgerStore(defaults: defaults)
        XCTAssertEqual(restored.name(for: .ming), "阿青")
        XCTAssertEqual(restored.name(for: .hong), "阿禾")
        XCTAssertEqual(restored.balanceSummary, "阿禾待结算给阿青")
        XCTAssertEqual(restored.currentBalance, balance)
    }

    @MainActor
    func testLedgerMembershipPersistsAndCombinedBalanceIncludesBothLedgers() throws {
        let suiteName = "TongZhangTests.ledgers.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = LedgerStore(defaults: defaults)
        store.add(Expense(title: "日常晚餐", amountInCents: 10000, paidBy: .ming, category: .food))
        store.add(Expense(title: "旅途车费", amountInCents: 4000, paidBy: .hong, category: .transport, ledger: .travel))
        let restored = LedgerStore(defaults: defaults)
        XCTAssertEqual(restored.expenses(in: .daily).map(\.title), ["日常晚餐"])
        XCTAssertEqual(restored.expenses(in: .travel).map(\.title), ["旅途车费"])
        XCTAssertEqual(restored.currentBalance.amountInCents, 3000)
        XCTAssertEqual(restored.currentBalance.receiver, .ming)
        restored.settle()
        XCTAssertTrue(restored.isSettled)
        XCTAssertEqual(restored.expenses.count, 2)
    }

    func testLegacyExpenseWithoutLedgerDecodesAsDaily() throws {
        let expense = Expense(title: "旧记录", amountInCents: 100, paidBy: .ming, category: .food)
        let data = try JSONEncoder().encode(expense)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "ledgerKind")
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(Expense.self, from: legacyData)
        XCTAssertEqual(decoded.ledger, .daily)
        XCTAssertEqual(decoded.amountInCents, 100)
    }

    @MainActor
    func testCorruptSnapshotIsProtectedAndRetryReadsRepairedData() async {
        let suiteName = "TongZhangTests.corrupt.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let key = "tongzhang.ledger.snapshot.v2"
        let source = LedgerStore(defaults: defaults)
        source.add(Expense(title: "保留的记录", amountInCents: 1200, paidBy: .ming, category: .food))
        let validData = defaults.data(forKey: key)!
        let damagedData = Data("invalid json".utf8)
        defaults.set(damagedData, forKey: key)
        let store = LedgerStore(defaults: defaults)
        XCTAssertFalse(store.canEdit)
        XCTAssertFalse(store.add(Expense(title: "不能覆盖", amountInCents: 100, paidBy: .hong, category: .food)))
        XCTAssertFalse(store.bindPartner(with: "123456"))
        store.unbindPartner()
        store.settle()
        XCTAssertEqual(defaults.data(forKey: key), damagedData)
        store.retryLoading()
        try? await Task.sleep(for: .milliseconds(450))
        XCTAssertFalse(store.canEdit)
        XCTAssertEqual(defaults.data(forKey: key), damagedData)
        defaults.set(validData, forKey: key)
        store.retryLoading()
        try? await Task.sleep(for: .milliseconds(450))
        XCTAssertTrue(store.canEdit)
        XCTAssertEqual(store.expenses.first?.title, "保留的记录")
    }

    @MainActor
    func testDuplicateExpenseIsRejected() {
        let store = LedgerStore(persistenceEnabled: false)
        let expense = Expense(title: "晚餐", amountInCents: 100, paidBy: .ming, category: .food)
        XCTAssertTrue(store.add(expense))
        XCTAssertFalse(store.add(expense))
        XCTAssertEqual(store.expenses.count, 1)
    }

    func testAmountInputPreservesCentsAndRejectsMalformedValues() {
        XCTAssertEqual(AmountInput.cents(" 12.30 "), 1230)
        XCTAssertEqual(AmountInput.cents("0.01"), 1)
        XCTAssertEqual(AmountInput.cents("999999999.99"), AmountInput.maximumCents)
        for value in ["", "-1", "12.345", "12元", "1e3", "1,000", "NaN", "1000000000", "9223372036854775807"] {
            XCTAssertNil(AmountInput.cents(value), value)
        }
        XCTAssertEqual(AmountInput.cents("33.33", maximum: 10_000), 3333)
        XCTAssertNil(AmountInput.cents("100.01", maximum: 10_000))
    }

    @MainActor
    func testStoreRejectsInvalidAmountsAndSplitsWithoutMutation() {
        let store = LedgerStore(persistenceEnabled: false)
        for split in [Split.amounts(ming: -1, hong: 101), .amounts(ming: 30, hong: 30), .ratios(ming: 5000, hong: 4000)] {
            XCTAssertFalse(store.add(Expense(title: "无效分摊", amountInCents: 100, paidBy: .ming, split: split, category: .food)))
        }
        XCTAssertFalse(store.add(Expense(title: "无效金额", amountInCents: 0, paidBy: .ming, category: .food)))
        XCTAssertTrue(store.expenses.isEmpty)
        XCTAssertTrue(store.add(Expense(title: "晚餐", amountInCents: 100, paidBy: .ming, category: .food, note: "一起做饭")))
        XCTAssertEqual(store.expenses.first?.note, "一起做饭")
    }

    @MainActor
    func testMonthFilterSeparatesYearsAndMonthBoundaries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day))!
        }
        let store = LedgerStore(expenses: [
            Expense(title: "月初", amountInCents: 101, paidBy: .ming, category: .food, date: date(2026, 9, 1)),
            Expense(title: "月末", amountInCents: 202, paidBy: .hong, category: .food, date: date(2026, 9, 30)),
            Expense(title: "下月", amountInCents: 300, paidBy: .ming, category: .food, date: date(2026, 10, 1)),
            Expense(title: "去年", amountInCents: 400, paidBy: .ming, category: .food, date: date(2025, 9, 1))
        ], persistenceEnabled: false)
        let filtered = store.expenses(inMonth: date(2026, 9, 19), calendar: calendar)
        XCTAssertEqual(filtered.map(\.title), ["月初", "月末"])
        XCTAssertEqual(filtered.reduce(Int64(0)) { $0 + $1.amountInCents }, 303)
    }

    func testEqualSplitUsesIntegerCentsAndRemainder() {
        let expense = Expense(title: "早餐", amountInCents: 101, paidBy: .ming, category: .food)
        XCTAssertEqual(SettlementEngine.shares(for: expense)[.ming], 50)
        XCTAssertEqual(SettlementEngine.shares(for: expense)[.hong], 51)
    }

    func testCombinedBalance() {
        let expenses = [
            Expense(title: "晚餐", amountInCents: 10000, paidBy: .ming, category: .food),
            Expense(title: "打车", amountInCents: 4000, paidBy: .hong, category: .transport)
        ]
        let result = SettlementEngine.balance(for: expenses)
        XCTAssertEqual(result.receiver, .ming)
        XCTAssertEqual(result.sender, .hong)
        XCTAssertEqual(result.amountInCents, 3000)
    }

    func testTreatDoesNotCreateBalanceWhenPayerTreats() {
        let expense = Expense(title: "礼物", amountInCents: 5000, paidBy: .ming, split: .hostTreat, category: .shopping)
        XCTAssertTrue(SettlementEngine.balance(for: [expense]).isSettled)
    }

    func testTreatMeansResponsiblePersonEvenWhenOtherPersonPaid() {
        let expense = Expense(title: "礼物", amountInCents: 5000, paidBy: .hong, split: .hostTreat, category: .shopping)
        let result = SettlementEngine.balance(for: [expense])
        XCTAssertEqual(result.receiver, .hong)
        XCTAssertEqual(result.sender, .ming)
        XCTAssertEqual(result.amountInCents, 5000)
    }

    func testNonSettlementExpenseIsIgnored() {
        let expense = Expense(title: "个人购物", amountInCents: 9999, paidBy: .ming, category: .shopping, requiresSettlement: false)
        XCTAssertTrue(SettlementEngine.balance(for: [expense]).isSettled)
    }

    func testCustomAmountsAreUsedExactly() {
        let expense = Expense(title: "酒店", amountInCents: 10000, paidBy: .ming, split: .amounts(ming: 7000, hong: 3000), category: .other)
        XCTAssertEqual(SettlementEngine.shares(for: expense)[.ming], 7000)
        XCTAssertEqual(SettlementEngine.shares(for: expense)[.hong], 3000)
        XCTAssertEqual(SettlementEngine.balance(for: [expense]).amountInCents, 3000)
    }

    func testRatioSplitUsesBasisPointsAndKeepsTotal() {
        let expense = Expense(title: "旅行", amountInCents: 9999, paidBy: .hong, split: .ratios(ming: 3333, hong: 6667), category: .other)
        let shares = SettlementEngine.shares(for: expense)
        XCTAssertEqual(shares[.ming]! + shares[.hong]!, 9999)
        XCTAssertEqual(shares[.ming], 3332)
    }

    @MainActor
    func testPartnerBindingRequiresSixDigitsAndCanUnbind() {
        let store = LedgerStore(persistenceEnabled: false)
        XCTAssertFalse(store.bindPartner(with: "123"))
        XCTAssertFalse(store.bindPartner(with: "123456\n"))
        XCTAssertFalse(store.bindPartner(with: "１２３４５６"))
        XCTAssertTrue(store.bindPartner(with: "428186"))
        store.unbindPartner()
        XCTAssertFalse(store.isPartnerBound)
    }

    @MainActor
    func testRetryLoadingReturnsToReady() async {
        let store = LedgerStore(persistenceEnabled: false)
        store.showPreviewError()
        XCTAssertEqual(store.loadState, .failed(message: "共同账本暂时无法刷新"))
        store.retryLoading()
        XCTAssertEqual(store.loadState, .loading)
        try? await Task.sleep(for: .milliseconds(450))
        XCTAssertEqual(store.loadState, .ready)
    }

    @MainActor
    func testLocalSnapshotRestoresExpensesAndRelationshipState() {
        let suiteName = "TongZhangTests.persistence.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstStore = LedgerStore(defaults: defaults)
        firstStore.add(Expense(title: "测试晚餐", amountInCents: 12800, paidBy: .hong, category: .food))
        _ = firstStore.bindPartner(with: "123456")
        firstStore.settle()

        let restoredStore = LedgerStore(defaults: defaults)
        XCTAssertEqual(restoredStore.expenses.first?.title, "测试晚餐")
        XCTAssertTrue(restoredStore.isPartnerBound)
        XCTAssertTrue(restoredStore.isSettled)
        XCTAssertEqual(restoredStore.partnerInviteCode, "123456")
        XCTAssertEqual(restoredStore.settlements.count, 1)
        restoredStore.add(Expense(title: "新增", amountInCents: 2000, paidBy: .ming, category: .food))
        XCTAssertEqual(restoredStore.currentBalance.amountInCents, 1000)
        XCTAssertEqual(restoredStore.currentBalance.receiver, .ming)
    }

    @MainActor
    func testSettlingTwiceIsIdempotentAndDeletingExpenseRecalculates() {
        let store = LedgerStore(persistenceEnabled: false)
        let expense = Expense(title: "晚餐", amountInCents: 10000, paidBy: .ming, category: .food)
        store.add(expense)
        store.settle()
        store.settle()
        XCTAssertEqual(store.settlements.count, 1)
        XCTAssertEqual(store.expenses.count, 1)
        XCTAssertTrue(store.isSettled)
        store.remove(expense)
        XCTAssertEqual(store.currentBalance.receiver, .hong)
        XCTAssertEqual(store.currentBalance.amountInCents, 5000)
    }
}
