import Foundation
import Combine

enum Person: String, CaseIterable, Codable, Identifiable {
    case ming = "小明"
    case hong = "小红"

    var id: String { rawValue }
}

enum ExpenseCategory: String, CaseIterable, Codable, Identifiable {
    case food = "餐饮"
    case transport = "交通"
    case entertainment = "娱乐"
    case shopping = "购物"
    case other = "其他"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .food: return "fork.knife"
        case .transport: return "car.fill"
        case .entertainment: return "ticket.fill"
        case .shopping: return "bag.fill"
        case .other: return "plus"
        }
    }
}

enum Split: Codable, Equatable, Hashable {
    case equal
    case hostTreat
    case partnerTreat
    case amounts(ming: Int64, hong: Int64)
    case ratios(ming: Int64, hong: Int64) // basis points, e.g. 50_00 = 50%
}

enum SplitOption: String, CaseIterable, Identifiable {
    case equal = "平分"
    case hostTreat = "我请客"
    case partnerTreat = "她请客"
    case customAmount = "按金额"
    case customRatio = "按比例"

    var id: String { rawValue }
}

enum AmountInput {
    static let maximumCents: Int64 = 99_999_999_999

    static func cents(_ input: String, maximum: Int64 = maximumCents) -> Int64? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.range(of: "^[0-9]+(?:\\.[0-9]{1,2})?$", options: .regularExpression) != nil,
              let decimal = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")),
              decimal >= 0, decimal <= Decimal(maximum) / 100 else { return nil }
        return NSDecimalNumber(decimal: decimal * 100).int64Value
    }
}

enum LedgerKind: String, Codable, CaseIterable, Identifiable {
    case daily
    case travel

    var id: String { rawValue }
    var title: String { self == .daily ? "日常共同账" : "我们的旅行" }
    var symbol: String { self == .daily ? "house" : "airplane" }
}

private enum LedgerValidation {
    static func name(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && value.count <= 16 && !value.contains(where: { $0.isNewline })
    }

    static func avatar(_ data: Data?) -> Bool {
        guard let data else { return true }
        return !data.isEmpty && data.count <= 300_000
    }

    static func inviteCode(_ code: String) -> Bool {
        code.count == 6 && code.utf8.allSatisfy { $0 >= 48 && $0 <= 57 }
    }

    static func date(_ value: Date) -> Bool {
        value.timeIntervalSinceReferenceDate.isFinite
            && value >= .distantPast && value <= .distantFuture
    }
}

struct Expense: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var amountInCents: Int64
    var paidBy: Person
    var split: Split
    var category: ExpenseCategory
    var date: Date
    var note: String?
    var requiresSettlement: Bool
    // Older snapshots have no ledger field and belong to the daily ledger.
    var ledgerKind: LedgerKind?
    var ledger: LedgerKind { ledgerKind ?? .daily }

    var isValid: Bool {
        guard amountInCents > 0, amountInCents <= AmountInput.maximumCents,
              LedgerValidation.date(date) else { return false }
        switch split {
        case let .amounts(ming, hong):
            return ming >= 0 && ming <= amountInCents && hong == amountInCents - ming
        case let .ratios(ming, hong):
            return ming >= 0 && ming <= 10_000 && hong == 10_000 - ming
        default:
            return true
        }
    }

    init(
        id: UUID = UUID(),
        title: String,
        amountInCents: Int64,
        paidBy: Person,
        split: Split = .equal,
        category: ExpenseCategory,
        date: Date = .now,
        note: String? = nil,
        requiresSettlement: Bool = true,
        ledger: LedgerKind = .daily
    ) {
        self.id = id
        self.title = title
        self.amountInCents = amountInCents
        self.paidBy = paidBy
        self.split = split
        self.category = category
        self.date = date
        self.note = note
        self.requiresSettlement = requiresSettlement
        self.ledgerKind = ledger
    }
}

struct SettlementBalance: Equatable {
    let receiver: Person?
    let sender: Person?
    let amountInCents: Int64

    var isSettled: Bool { amountInCents == 0 }
    var summary: String {
        guard let sender, let receiver else { return "已平账" }
        return "\(sender.rawValue)待结算给\(receiver.rawValue)"
    }
}

enum LedgerLoadState: Equatable {
    case loading
    case ready
    case failed(message: String)
}

private struct LedgerSnapshot: Codable {
    var expenses: [Expense]
    var settlements: [Settlement]
    var isPartnerBound: Bool
    var partnerInviteCode: String
    var mingName: String? = nil
    var hongName: String? = nil
    var mingAvatar: Data? = nil
    var hongAvatar: Data? = nil

    var isValid: Bool {
        guard mingName.map(LedgerValidation.name) ?? true,
              hongName.map(LedgerValidation.name) ?? true,
              LedgerValidation.avatar(mingAvatar), LedgerValidation.avatar(hongAvatar),
              (partnerInviteCode.isEmpty && !isPartnerBound) || LedgerValidation.inviteCode(partnerInviteCode),
              expenses.allSatisfy(\.isValid),
              Set(expenses.map(\.id)).count == expenses.count,
              Set(settlements.map(\.id)).count == settlements.count,
              settlements.allSatisfy({ $0.sender != $0.receiver && $0.amountInCents > 0 && LedgerValidation.date($0.date) }) else { return false }
        var total: Int64 = 0
        for amount in expenses.map(\.amountInCents) + settlements.map(\.amountInCents) {
            let result = total.addingReportingOverflow(amount)
            guard !result.overflow, result.partialValue <= Int64.max / 2 else { return false }
            total = result.partialValue
        }
        return true
    }
}

struct Settlement: Identifiable, Codable, Equatable {
    var id = UUID()
    let sender: Person
    let receiver: Person
    let amountInCents: Int64
    var date = Date()
}

enum SettlementEngine {
    static func shares(for expense: Expense) -> [Person: Int64] {
        guard expense.requiresSettlement else { return [.ming: 0, .hong: 0] }
        switch expense.split {
        case .equal:
            let ming = expense.amountInCents / 2
            return [.ming: ming, .hong: expense.amountInCents - ming]
        case .hostTreat:
            return [.ming: expense.amountInCents, .hong: 0]
        case .partnerTreat:
            return [.ming: 0, .hong: expense.amountInCents]
        case let .amounts(ming, hong):
            return [.ming: ming, .hong: hong]
        case let .ratios(ming, _):
            let mingShare = expense.amountInCents * ming / 10_000
            return [.ming: mingShare, .hong: expense.amountInCents - mingShare]
        }
    }

    static func balance(for expenses: [Expense], settlements: [Settlement] = []) -> SettlementBalance {
        var net: [Person: Int64] = [.ming: 0, .hong: 0]
        for expense in expenses where expense.requiresSettlement {
            let shares = shares(for: expense)
            net[expense.paidBy, default: 0] += expense.amountInCents
            for person in Person.allCases { net[person, default: 0] -= shares[person, default: 0] }
        }
        for settlement in settlements {
            net[settlement.sender, default: 0] += settlement.amountInCents
            net[settlement.receiver, default: 0] -= settlement.amountInCents
        }
        let mingNet = net[.ming, default: 0]
        guard mingNet != 0 else { return SettlementBalance(receiver: nil, sender: nil, amountInCents: 0) }
        return mingNet > 0
            ? SettlementBalance(receiver: .ming, sender: .hong, amountInCents: mingNet)
            : SettlementBalance(receiver: .hong, sender: .ming, amountInCents: -mingNet)
    }
}

@MainActor
final class LedgerStore: ObservableObject {
    @Published private(set) var expenses: [Expense]
    @Published private(set) var settlements: [Settlement]
    var isSettled: Bool { currentBalance.isSettled }
    @Published private(set) var isPartnerBound: Bool
    @Published private(set) var partnerInviteCode: String
    @Published private(set) var mingName = "小明"
    @Published private(set) var hongName = "小红"
    @Published private(set) var mingAvatar: Data?
    @Published private(set) var hongAvatar: Data?
    @Published private(set) var loadState: LedgerLoadState = .ready
    @Published private(set) var saveError: String?

    private let defaults: UserDefaults
    private let persistenceKey = "tongzhang.ledger.snapshot.v2"
    private let persistenceEnabled: Bool
    var canEdit: Bool { loadState == .ready }

    init(
        expenses: [Expense]? = nil,
        defaults: UserDefaults = .standard,
        persistenceEnabled: Bool = true
    ) {
        self.defaults = defaults
        self.persistenceEnabled = persistenceEnabled

        _expenses = Published(initialValue: expenses ?? [])
        _settlements = Published(initialValue: [])
        _isPartnerBound = Published(initialValue: false)
        _partnerInviteCode = Published(initialValue: "")
        restore()
    }

    private func restore() {
        guard persistenceEnabled else { loadState = .ready; return }
        guard let object = defaults.object(forKey: persistenceKey) else {
            loadState = .ready
            return
        }
        guard let data = object as? Data,
              let snapshot = try? JSONDecoder().decode(LedgerSnapshot.self, from: data),
              snapshot.isValid else {
            loadState = .failed(message: "本地账本读取失败，原始数据已保留，请重试")
            return
        }
        expenses = snapshot.expenses
        settlements = snapshot.settlements
        isPartnerBound = snapshot.isPartnerBound
        partnerInviteCode = snapshot.partnerInviteCode
        mingName = snapshot.mingName ?? "小明"
        hongName = snapshot.hongName ?? "小红"
        mingAvatar = snapshot.mingAvatar
        hongAvatar = snapshot.hongAvatar
        loadState = .ready
    }

    private func validSnapshot(expenses: [Expense], settlements: [Settlement]) -> Bool {
        LedgerSnapshot(expenses: expenses, settlements: settlements, isPartnerBound: isPartnerBound,
                       partnerInviteCode: partnerInviteCode, mingName: mingName, hongName: hongName,
                       mingAvatar: mingAvatar, hongAvatar: hongAvatar).isValid
    }

    var currentBalance: SettlementBalance {
        SettlementEngine.balance(for: expenses, settlements: settlements)
    }

    func name(for person: Person) -> String { person == .ming ? mingName : hongName }

    func avatar(for person: Person) -> Data? { person == .ming ? mingAvatar : hongAvatar }

    @discardableResult
    func updateAvatar(_ data: Data?, for person: Person) -> Bool {
        guard canEdit, LedgerValidation.avatar(data) else { return false }
        if person == .ming { mingAvatar = data } else { hongAvatar = data }
        persist()
        return true
    }

    var balanceSummary: String {
        guard let sender = currentBalance.sender, let receiver = currentBalance.receiver else { return "已平账" }
        return "\(name(for: sender))待结算给\(name(for: receiver))"
    }

    @discardableResult
    func updateNames(ming: String, hong: String) -> Bool {
        let first = ming.trimmingCharacters(in: .whitespacesAndNewlines)
        let second = hong.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canEdit, LedgerValidation.name(first), LedgerValidation.name(second) else { return false }
        mingName = first
        hongName = second
        persist()
        return true
    }

    func expenses(inMonth month: Date = .now, calendar: Calendar = .current) -> [Expense] {
        expenses.filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
    }

    func expenses(in ledger: LedgerKind) -> [Expense] {
        expenses.filter { $0.ledger == ledger }.sorted { $0.date > $1.date }
    }

    @discardableResult
    func add(_ expense: Expense) -> Bool {
        guard canEdit, validSnapshot(expenses: expenses + [expense], settlements: settlements) else { return false }
        expenses.insert(expense, at: 0)
        persist()
        return true
    }

    func remove(_ expense: Expense) {
        guard canEdit else { return }
        expenses.removeAll { $0.id == expense.id }
        persist()
    }

    func settle(expectedBalance: SettlementBalance? = nil) {
        guard canEdit else { return }
        let balance = currentBalance
        if let expectedBalance, expectedBalance != balance {
            saveError = "结算金额已变化，请重新确认"
            return
        }
        guard let sender = balance.sender, let receiver = balance.receiver,
              balance.amountInCents > 0 else { return }
        let settlement = Settlement(sender: sender, receiver: receiver, amountInCents: balance.amountInCents)
        guard validSnapshot(expenses: expenses, settlements: settlements + [settlement]) else {
            saveError = "账本金额已达上限，暂时无法结算"
            return
        }
        settlements.append(settlement)
        persist()
    }
    func bindPartner(with code: String) -> Bool {
        guard canEdit, LedgerValidation.inviteCode(code) else { return false }
        isPartnerBound = true
        partnerInviteCode = code
        persist()
        return true
    }
    func unbindPartner() {
        guard canEdit else { return }
        isPartnerBound = false
        persist()
    }
    func retryLoading() {
        loadState = .loading
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            restore()
        }
    }

    func showPreviewError() { loadState = .failed(message: "共同账本暂时无法刷新") }

    private func persist() {
        guard persistenceEnabled, canEdit else { return }
        let snapshot = LedgerSnapshot(
            expenses: expenses,
            settlements: settlements,
            isPartnerBound: isPartnerBound,
            partnerInviteCode: partnerInviteCode,
            mingName: mingName,
            hongName: hongName,
            mingAvatar: mingAvatar,
            hongAvatar: hongAvatar
        )
        do {
            let data = try JSONEncoder().encode(snapshot)
            defaults.set(data, forKey: persistenceKey)
            saveError = nil
        } catch {
            saveError = "本地保存失败，请稍后重试"
        }
    }

    static let preview = LedgerStore(expenses: [
        Expense(title: "晚餐", amountInCents: 16_800, paidBy: .ming, category: .food),
        Expense(title: "打车", amountInCents: 4_200, paidBy: .hong, category: .transport),
        Expense(title: "电影票", amountInCents: 12_000, paidBy: .ming, category: .entertainment)
    ], persistenceEnabled: false)
}
