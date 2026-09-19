import SwiftUI
import UIKit
import PhotosUI
import ImageIO

struct ContentView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var selectedTab = 0
    @State private var showingExpense = false
    @State private var showingSettlement = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(showingExpense: $showingExpense, showingSettlement: $showingSettlement, showBills: { selectedTab = 1 }).tabItem { Label("首页", systemImage: "house") }.tag(0)
            BillsView().tabItem { Label("账单", systemImage: "list.bullet") }.tag(1)
            LedgersView().tabItem { Label("账本", systemImage: "rectangle.stack") }.tag(2)
            ProfileView().tabItem { Label("我们", systemImage: "person.2") }.tag(3)
        }
        .tint(Theme.terra)
        .sheet(isPresented: $showingExpense) { ExpenseSheet() }
        .sheet(isPresented: $showingSettlement) { SettlementSheet() }
        .overlay(alignment: .bottomTrailing) {
            if selectedTab == 0 || selectedTab == 1 {
            Button { showingExpense = true } label: {
                Image(systemName: "plus").font(.title2.weight(.medium)).frame(width: 56, height: 56)
            }
            .foregroundStyle(Theme.paper)
            .background(Theme.ink, in: Circle())
            .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
            .padding(.trailing, 22)
            .padding(.bottom, 76)
            .disabled(!store.canEdit)
            .accessibilityLabel("记一笔")
            }
        }
    }
}

enum Theme {
    static let paper = adaptive(light: UIColor(red: 0.97, green: 0.96, blue: 0.93, alpha: 1), dark: UIColor(red: 0.10, green: 0.11, blue: 0.10, alpha: 1))
    static let ink = adaptive(light: UIColor(red: 0.14, green: 0.15, blue: 0.13, alpha: 1), dark: UIColor(red: 0.94, green: 0.93, blue: 0.89, alpha: 1))
    static let terra = adaptive(light: UIColor(red: 0.74, green: 0.46, blue: 0.36, alpha: 1), dark: UIColor(red: 0.88, green: 0.58, blue: 0.46, alpha: 1))
    static let terraSoft = adaptive(light: UIColor(red: 0.94, green: 0.87, blue: 0.83, alpha: 1), dark: UIColor(red: 0.28, green: 0.18, blue: 0.15, alpha: 1))
    static let sage = adaptive(light: UIColor(red: 0.43, green: 0.55, blue: 0.50, alpha: 1), dark: UIColor(red: 0.54, green: 0.68, blue: 0.61, alpha: 1))
    static let sageSoft = adaptive(light: UIColor(red: 0.87, green: 0.91, blue: 0.88, alpha: 1), dark: UIColor(red: 0.16, green: 0.23, blue: 0.20, alpha: 1))

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light })
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: LedgerStore
    @Binding var showingExpense: Bool
    @Binding var showingSettlement: Bool
    var showBills: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(Date.now, format: .dateTime.month().day().weekday()).eyebrow()
                    Text("你好，\(store.mingName)").font(.system(size: 28, weight: .bold, design: .rounded)).padding(.top, 4)
                    HStack { Text("和\(store.hongName)的共同生活").muted(); Spacer(); Avatars() }.padding(.top, 8)

                    switch store.loadState {
                    case .loading:
                        HStack(spacing: 9) { ProgressView().tint(Theme.terra); Text("正在读取共同账本…").font(.caption).foregroundStyle(.secondary) }.padding(.top, 22)
                    case let .failed(message):
                        HStack(spacing: 10) { Image(systemName: "exclamationmark.triangle"); Text(message).font(.caption); Spacer(); Button("重试") { store.retryLoading() }.font(.caption.weight(.bold)) }.foregroundStyle(Theme.terra).padding(.top, 22)
                    case .ready:
                        EmptyView()
                    }

                    if let saveError = store.saveError {
                        Label(saveError, systemImage: "externaldrive.badge.exclamationmark")
                            .font(.caption)
                            .foregroundStyle(Theme.terra)
                            .padding(.top, 12)
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        Text("本月一起花了").sectionLabel()
                        Text(store.expenses(inMonth: .now).reduce(Int64(0)) { $0 + $1.amountInCents }.currency)
                            .font(.system(size: 46, weight: .medium, design: .monospaced))
                            .lineLimit(1).minimumScaleFactor(0.5)
                        Text("本月 \(store.expenses(inMonth: .now).count) 笔共同记录").font(.caption).foregroundStyle(Theme.sage)
                    }.padding(.top, 52).padding(.bottom, 26)

                    Divider()
                    Button { showingSettlement = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.up.right").frame(width: 30, height: 30).background(Theme.terraSoft, in: Circle()).foregroundStyle(Theme.terra)
                            VStack(alignment: .leading, spacing: 4) { Text(store.balanceSummary).font(.subheadline.weight(.semibold)); Text(store.currentBalance.amountInCents.currency).font(.title3.monospaced()) }
                            Spacer(); Text(store.currentBalance.isSettled ? "结算记录" : "去结算 →").font(.caption.weight(.bold)).foregroundStyle(Theme.terra)
                        }.foregroundStyle(Theme.ink).padding(.vertical, 18)
                    }.disabled(!store.canEdit)
                    Divider()

                    HStack {
                        VStack(alignment: .leading) { Text("RECENT ACTIVITY").eyebrow(); Text("最近记录").font(.title3.weight(.bold)) }
                        Spacer()
                        Button("查看全部", action: showBills).font(.caption.weight(.bold)).foregroundStyle(Theme.terra)
                    }.padding(.top, 30).padding(.bottom, 8)
                    if store.expenses.isEmpty && store.canEdit {
                        ContentUnavailableView {
                            Label("还没有共同记录", systemImage: "book.closed")
                        } description: {
                            Text("从一顿晚餐开始，记下共同生活。")
                        } actions: {
                            Button("记第一笔") { showingExpense = true }.buttonStyle(.borderedProminent)
                        }
                    }
                    ForEach(store.expenses.sorted { $0.date > $1.date }.prefix(4)) { expense in ExpenseRow(expense: expense) }
                }.padding(.horizontal, 22).padding(.bottom, 100)
            }.background(Theme.paper).toolbar { ToolbarItem(placement: .topBarLeading) { Text("同账").font(.headline.weight(.bold)) } }
        }
    }
}

struct ExpenseRow: View {
    @EnvironmentObject private var store: LedgerStore
    let expense: Expense
    @State private var showingDetail = false
    var body: some View {
        Button { showingDetail = true } label: {
        HStack(spacing: 12) {
            Image(systemName: expense.category.symbol)
                .frame(width: 34, height: 34)
                .background(expense.paidBy == .ming ? Theme.terraSoft : Theme.sageSoft, in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(expense.paidBy == .ming ? Theme.terra : Theme.sage)
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.title).font(.subheadline.weight(.semibold))
                Text("\(expense.category.rawValue) · \(store.name(for: expense.paidBy))支付")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(expense.amountInCents.currency).font(.subheadline.monospaced())
                .lineLimit(1).minimumScaleFactor(0.7).layoutPriority(1)
        }.padding(.vertical, 12).overlay(alignment: .bottom) { Divider() }
        }.buttonStyle(.plain)
            .sheet(isPresented: $showingDetail) { ExpenseDetailView(expense: expense) }
    }
}

private struct ExpenseDetailView: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss
    let expense: Expense
    @State private var confirmingDelete = false

    private var splitTitle: String {
        switch expense.split {
        case .equal: return "平分"
        case .hostTreat: return "\(store.mingName)请客"
        case .partnerTreat: return "\(store.hongName)请客"
        case .amounts: return "按金额分摊"
        case .ratios: return "按比例分摊"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Label(expense.category.rawValue, systemImage: expense.category.symbol)
                        .font(.subheadline).foregroundStyle(Theme.terra)
                    Text(expense.title).font(.title2.weight(.semibold))
                    Text(expense.amountInCents.currency)
                        .font(.largeTitle.monospacedDigit()).lineLimit(1).minimumScaleFactor(0.5)
                    Divider()
                    LabeledContent("付款人", value: store.name(for: expense.paidBy))
                    LabeledContent("账本", value: expense.ledger.title)
                    LabeledContent("消费日期") { Text(expense.date, style: .date) }
                    Divider()
                    if expense.requiresSettlement {
                        Text(splitTitle).font(.headline)
                        ForEach(Person.allCases) { person in
                            LabeledContent("\(store.name(for: person))承担",
                                           value: (SettlementEngine.shares(for: expense)[person] ?? 0).currency)
                        }
                    } else {
                        Text("不参与共同结算").foregroundStyle(.secondary)
                    }
                    if let note = expense.note, !note.isEmpty {
                        Divider()
                        Text("备注").sectionLabel()
                        Text(note).textSelection(.enabled)
                    }
                }.padding(24)
            }
            .background(Theme.paper).foregroundStyle(Theme.ink)
            .navigationTitle("消费详情").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) { confirmingDelete = true } label: { Image(systemName: "trash") }
                        .accessibilityLabel("删除消费").disabled(!store.canEdit)
                }
            }
            .confirmationDialog("删除这笔记录？", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("删除", role: .destructive) { store.remove(expense); dismiss() }
                Button("取消", role: .cancel) {}
            } message: { Text("删除后会重新计算结算金额，已记录的结算转账仍会保留。") }
        }.tint(Theme.terra)
    }
}

struct Avatars: View {
    @EnvironmentObject private var store: LedgerStore
    var body: some View {
        HStack(spacing: -8) {
            PersonAvatar(person: .ming)
            PersonAvatar(person: .hong)
        }.accessibilityLabel("\(store.mingName)和\(store.hongName)")
    }
}
private struct PersonAvatar: View {
    @EnvironmentObject private var store: LedgerStore
    let person: Person
    var body: some View {
        Group {
            if let data = store.avatar(for: person), let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(String(store.name(for: person).prefix(1)))
                    .font(.caption.weight(.bold))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(person == .ming ? Theme.terraSoft : Theme.sageSoft)
            }
        }.frame(width: 38, height: 38).clipShape(Circle())
            .overlay(Circle().stroke(Theme.paper, lineWidth: 2))
    }
}

private struct AvatarPicker: View {
    @EnvironmentObject private var store: LedgerStore
    let person: Person
    @State private var selection: PhotosPickerItem?
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 8) {
            PhotosPicker(selection: $selection, matching: .images) {
                HStack { PersonAvatar(person: person); Text(store.name(for: person)).lineLimit(2) }
            }.disabled(loading || !store.canEdit)
                .accessibilityLabel("更换\(store.name(for: person))的头像")
            if loading { ProgressView() }
            if store.avatar(for: person) != nil {
                Button("移除头像", role: .destructive) { store.updateAvatar(nil, for: person) }.font(.caption)
                    .disabled(loading || !store.canEdit)
            }
        }
        .task(id: selection) {
            guard let selection else { return }
            loading = true
            defer { loading = false }
            do {
                guard let data = try await selection.loadTransferable(type: Data.self),
                      let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceThumbnailMaxPixelSize: 256,
                        kCGImageSourceCreateThumbnailWithTransform: true
                      ] as CFDictionary),
                      let jpeg = UIImage(cgImage: thumbnail).jpegData(compressionQuality: 0.8) else {
                    error = "这张照片暂时无法读取，请换一张"
                    return
                }
                guard !Task.isCancelled else { return }
                if !store.updateAvatar(jpeg, for: person) { error = "头像未保存，请稍后重试" }
            } catch { self.error = "照片读取失败，请重试" }
        }
        .alert("无法更新头像", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("好", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }
}
struct BillsView: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var pendingDelete: Expense?
    @State private var selectedMonth = Date.now

    private struct ExpenseGroup: Identifiable {
        let id: String
        let expenses: [Expense]
    }

    private var groupedExpenses: [ExpenseGroup] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        let groups = Dictionary(grouping: monthExpenses) { calendar.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { date in
            ExpenseGroup(id: formatter.string(from: date), expenses: groups[date] ?? [])
        }
    }

    private var calendar: Calendar { .current }
    private var monthExpenses: [Expense] { store.expenses(inMonth: selectedMonth, calendar: calendar) }
    private var total: Int64 { monthExpenses.reduce(0) { $0 + $1.amountInCents } }
    private var mingTotal: Int64 { monthExpenses.filter { $0.paidBy == .ming }.reduce(0) { $0 + $1.amountInCents } }
    private var hongTotal: Int64 { monthExpenses.filter { $0.paidBy == .hong }.reduce(0) { $0 + $1.amountInCents } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    let layout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
                        : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
                    layout {
                        stat("共同支出", total)
                        stat("\(store.mingName)支付", mingTotal)
                        stat("\(store.hongName)支付", hongTotal)
                    }
                } header: {
                    MonthPicker(selection: $selectedMonth)
                }.listRowBackground(Color.clear)
                if monthExpenses.isEmpty {
                    ContentUnavailableView("还没有共同记录", systemImage: "tray", description: Text("记下第一笔一起生活的消费吧")).listRowBackground(Color.clear)
                } else {
                    ForEach(groupedExpenses) { group in
                        Section(group.id) {
                            ForEach(group.expenses.sorted { $0.date > $1.date }) { expense in
                                ExpenseRow(expense: expense).listRowSeparator(.hidden).swipeActions {
                                    Button(role: .destructive) { pendingDelete = expense } label: { Label("删除", systemImage: "trash") }
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden).background(Theme.paper)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 90) }
            .navigationTitle("账单").navigationBarTitleDisplayMode(.large)
            .confirmationDialog("删除这笔记录？", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
                Button("删除", role: .destructive) { if let pendingDelete { store.remove(pendingDelete) }; pendingDelete = nil }
                Button("取消", role: .cancel) { pendingDelete = nil }
            } message: { Text("删除后会重新计算结算金额，已记录的结算转账仍会保留。原始消费记录无法恢复。") }
        }
    }
}

private struct MonthPicker: View {
    @Binding var selection: Date
    private let calendar = Calendar.current

    var body: some View {
        HStack {
            Button { selection = calendar.date(byAdding: .month, value: -1, to: selection) ?? selection } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("上一个月")
            Spacer()
            Text(selection, format: .dateTime.year().month()).font(.subheadline.weight(.semibold))
            Spacer()
            Button { selection = calendar.date(byAdding: .month, value: 1, to: selection) ?? selection } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel("下一个月")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.ink)
        .textCase(nil)
    }
}
struct LedgersView: View {
    @EnvironmentObject private var store: LedgerStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(LedgerKind.allCases) { ledger in
                        NavigationLink {
                            LedgerDetailView(ledger: ledger)
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: ledger.symbol)
                                    .font(.title2).frame(width: 44, height: 52)
                                    .foregroundStyle(ledger == .daily ? Theme.terra : Theme.sage)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(ledger.title).font(.headline)
                                    Text("\(store.expenses(in: ledger).count) 笔记录")
                                        .font(.caption).foregroundStyle(.secondary)
                                    Text(store.expenses(in: ledger).reduce(Int64(0)) { $0 + $1.amountInCents }.currency)
                                        .font(.title2.monospacedDigit()).lineLimit(1).minimumScaleFactor(0.6)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }.padding(.vertical, 28).foregroundStyle(Theme.ink)
                        }
                        Divider()
                    }
                }.padding(.horizontal, 22)
            }
            .background(Theme.paper).navigationTitle("账本")
        }
    }
}

private struct LedgerDetailView: View {
    @EnvironmentObject private var store: LedgerStore
    let ledger: LedgerKind
    @State private var showingExpense = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                Text("一起花了").sectionLabel()
                Text(store.expenses(in: ledger).reduce(Int64(0)) { $0 + $1.amountInCents }.currency)
                    .font(.largeTitle.monospacedDigit()).lineLimit(1).minimumScaleFactor(0.5)
                if store.expenses(in: ledger).isEmpty {
                    ContentUnavailableView("还没有记录", systemImage: ledger.symbol)
                }
                ForEach(store.expenses(in: ledger)) { expense in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(expense.date, style: .date).font(.caption).foregroundStyle(.secondary)
                        ExpenseRow(expense: expense)
                        if let note = expense.note {
                            Text(note).font(.caption).foregroundStyle(.secondary).padding(.top, 6)
                        }
                    }
                }
            }.padding(22).padding(.bottom, 80)
        }
        .background(Theme.paper).navigationTitle(ledger.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingExpense = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("在此账本记一笔").disabled(!store.canEdit)
            }
        }
        .sheet(isPresented: $showingExpense) { ExpenseSheet(initialLedger: ledger) }
    }
}
struct ProfileView: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("tongzhang.appearance") private var appearance = "system"
    @State private var showingEdit = false
    @State private var showingUnbind = false

    var body: some View {
        NavigationStack {
            ScrollView {
            VStack(spacing: 18) {
                Text("YOUR SPACE").eyebrow()
                Text("我们").font(.largeTitle.bold())
                Text("只属于你们两个人的设置").muted()
                Avatars().scaleEffect(1.5).padding(22)
                let avatarLayout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 24))
                    : AnyLayout(HStackLayout(spacing: 24))
                avatarLayout { AvatarPicker(person: .ming); AvatarPicker(person: .hong) }
                if store.isPartnerBound {
                    Text("\(store.mingName) & \(store.hongName)").font(.title3.bold())
                    Text("一起记录生活").muted()
                    HStack { Button("编辑关系资料") { showingEdit = true }.buttonStyle(.bordered); Button("解除绑定") { showingUnbind = true }.buttonStyle(.bordered).tint(Theme.terra) }
                } else {
                    ContentUnavailableView("还没有绑定伴侣", systemImage: "person.2", description: Text("输入对方的邀请码，开始共同记录")).padding(.vertical, 8)
                    Button("绑定伴侣") { showingEdit = true }
                        .buttonStyle(.borderedProminent).tint(Theme.ink).foregroundStyle(Theme.paper)
                }
                Divider().padding(.vertical)
                Picker(selection: $appearance) {
                    Text("跟随系统").tag("system")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                } label: { Label("外观", systemImage: "circle.lefthalf.filled") }
                .pickerStyle(.menu)
                LabeledContent("记账货币", value: "人民币 CNY")
            }
            .padding(22)
            .padding(.bottom, 100)
            .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.paper)
            .navigationBarHidden(true)
            .sheet(isPresented: $showingEdit) { RelationshipEditor() }
            .confirmationDialog("解除伴侣绑定？", isPresented: $showingUnbind, titleVisibility: .visible) {
                Button("解除绑定", role: .destructive) { store.unbindPartner() }
                Button("取消", role: .cancel) { }
            } message: { Text("解除本机关系状态，已有消费和结算记录会保留。") }
        }
    }
}

struct RelationshipEditor: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss
    @State private var mingName = "小明"
    @State private var hongName = "小红"
    @State private var inviteCode = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("你们的称呼") {
                    TextField("你的昵称", text: $mingName)
                    TextField("对方的昵称", text: $hongName)
                }
                if !store.isPartnerBound {
                    Section("本地模拟绑定") {
                        TextField("输入 6 位邀请码", text: $inviteCode).keyboardType(.numberPad)
                        Button("确认绑定") {
                            guard store.updateNames(ming: mingName, hong: hongName) else { errorMessage = "昵称需为 1 至 16 个字符"; return }
                            if store.bindPartner(with: inviteCode) { dismiss() } else { errorMessage = "请输入有效的邀请码" }
                        }
                    }
                }
                if let errorMessage { Text(errorMessage).font(.caption).foregroundStyle(.red) }
            }
            .navigationTitle("关系资料")
            .onAppear { mingName = store.mingName; hongName = store.hongName }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if store.updateNames(ming: mingName, hong: hongName) { dismiss() }
                        else { errorMessage = "昵称需为 1 至 16 个字符" }
                    }.disabled(!store.canEdit)
                }
            }
        }
    }
}

struct ExpenseSheet: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @FocusState private var amountFocused: Bool
    @State private var title = ""
    @State private var payer = Person.ming
    @State private var splitOption = SplitOption.equal
    @State private var mingShare = "0.00"
    @State private var hongShare = "0.00"
    @State private var mingRatio = "50"
    @State private var category = ExpenseCategory.food
    @State private var note = ""
    @State private var expenseDate = Date.now
    @State private var validationMessage: String?
    @State private var ledger: LedgerKind

    init(initialLedger: LedgerKind = .daily) {
        _ledger = State(initialValue: initialLedger)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("这次一起花了").sectionLabel()
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("¥").font(.title2).foregroundStyle(Theme.terra)
                            TextField("0.00", text: $amount)
                                .keyboardType(.decimalPad).font(.system(size: 40, weight: .medium, design: .monospaced))
                                .focused($amountFocused).accessibilityLabel("消费金额，元")
                        }
                    }.padding(.vertical, 12)
                    Divider()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("消费分类").sectionLabel()
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 12)], spacing: 12) {
                            ForEach(ExpenseCategory.allCases) { item in
                                Button { category = item } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: item.symbol).font(.title3).frame(height: 24)
                                        Text(item.rawValue).font(.caption)
                                    }
                                    .frame(maxWidth: .infinity).frame(minHeight: 66)
                                    .foregroundStyle(category == item ? Theme.terra : Theme.ink)
                                    .background(category == item ? Theme.terraSoft : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                                }.buttonStyle(.plain)
                                    .accessibilityAddTraits(category == item ? .isSelected : [])
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                    Text("谁先付的？").sectionLabel()
                    Picker("付款人", selection: $payer) { ForEach(Person.allCases) { Text(store.name(for: $0)).tag($0) } }.pickerStyle(.segmented)
                }
                    Divider()
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("怎么分？").sectionLabel()
                        Spacer()
                        Picker("分摊方式", selection: $splitOption) {
                            ForEach(SplitOption.allCases) { option in
                                Text(splitLabel(option)).tag(option)
                            }
                        }.pickerStyle(.menu)
                    }
                    if splitOption == .customAmount {
                        TextField("\(store.mingName)承担 ¥", text: $mingShare).keyboardType(.decimalPad)
                        TextField("\(store.hongName)承担 ¥", text: $hongShare).keyboardType(.decimalPad)
                    }
                    if splitOption == .customRatio {
                        TextField("\(store.mingName)比例（0 - 100）", text: $mingRatio).keyboardType(.decimalPad)
                        Text("\(store.hongName)承担 \(hongRatioText)%").font(.caption).foregroundStyle(.secondary)
                    }
                }
                    Divider()
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("放入账本").sectionLabel()
                        Spacer()
                        Picker("账本", selection: $ledger) {
                        ForEach(LedgerKind.allCases) { Text($0.title).tag($0) }
                        }.pickerStyle(.menu)
                    }
                    TextField("消费名称（可选）", text: $title)
                    DatePicker("消费日期", selection: $expenseDate, in: ...Date.now, displayedComponents: .date)
                    TextField("备注（可选）", text: $note, axis: .vertical).lineLimit(2...4)
                }
                }.padding(22)
            }
            .background(Theme.paper).foregroundStyle(Theme.ink)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("记一笔")
            .navigationBarTitleDisplayMode(.inline)
            .task { amountFocused = true }
            .alert("请检查这笔记录", isPresented: Binding(
                get: { validationMessage != nil },
                set: { if !$0 { validationMessage = nil } }
            )) {
                Button("继续编辑", role: .cancel) { validationMessage = nil }
            } message: { Text(validationMessage ?? "") }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存", action: save).disabled(!store.canEdit) }
            }
        }
        .tint(Theme.terra)
    }

    private var hongRatioText: String {
        guard let ratio = AmountInput.cents(mingRatio, maximum: 10_000) else { return "—" }
        return NSDecimalNumber(decimal: Decimal(10_000 - ratio) / 100).stringValue
    }

    private func splitLabel(_ option: SplitOption) -> String {
        switch option {
        case .hostTreat: return "\(store.mingName)请客"
        case .partnerTreat: return "\(store.hongName)请客"
        default: return option.rawValue
        }
    }

    private func cents(_ value: String) -> Int64? {
        AmountInput.cents(value)
    }

    private func save() {
        guard let total = cents(amount), total > 0 else { validationMessage = "金额需大于 0、最多两位小数，且不超过 999,999,999.99 元"; return }
        let split: Split
        switch splitOption {
        case .equal: split = .equal
        case .hostTreat: split = .hostTreat
        case .partnerTreat: split = .partnerTreat
        case .customAmount:
            guard let ming = cents(mingShare), let hong = cents(hongShare), ming + hong == total else { validationMessage = "两人的承担金额必须加起来等于总额"; return }
            split = .amounts(ming: ming, hong: hong)
        case .customRatio:
            guard let ming = AmountInput.cents(mingRatio, maximum: 10_000) else { validationMessage = "比例需要在 0 到 100 之间，最多两位小数"; return }
            split = .ratios(ming: ming, hong: 10_000 - ming)
        }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard store.add(Expense(title: cleanTitle.isEmpty ? category.rawValue : cleanTitle, amountInCents: total, paidBy: payer, split: split, category: category, date: expenseDate, note: cleanNote.isEmpty ? nil : cleanNote, ledger: ledger)) else {
            validationMessage = "请检查金额和分摊方式"
            return
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
struct SettlementSheet: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss
    @State private var pendingBalance: SettlementBalance?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("结算").font(.title2.bold())
                Avatars()
                Text(store.balanceSummary).foregroundStyle(.secondary)
                Text(store.currentBalance.amountInCents.currency)
                    .font(.system(size: 42, design: .monospaced))
                    .minimumScaleFactor(0.6).lineLimit(1)
                Button("标记为已结算") {
                    pendingBalance = store.currentBalance
                }
                    .buttonStyle(.borderedProminent).tint(Theme.ink).foregroundStyle(Theme.paper)
                    .disabled(store.currentBalance.isSettled || !store.canEdit)
                if let error = store.saveError { Text(error).font(.caption).foregroundStyle(Theme.terra) }
                if store.settlements.isEmpty {
                    ContentUnavailableView("暂无结算记录", systemImage: "checkmark.circle")
                }
                ForEach(store.settlements.reversed()) { settlement in
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(store.name(for: settlement.sender)) → \(store.name(for: settlement.receiver))")
                            Text(settlement.date, style: .date).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(settlement.amountInCents.currency).monospacedDigit()
                    }.font(.subheadline)
                }
            }.padding(22)
        }
        .background(Theme.paper).foregroundStyle(Theme.ink)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .confirmationDialog("确认已经完成转账？", isPresented: Binding(
            get: { pendingBalance != nil },
            set: { if !$0 { pendingBalance = nil } }
        ), titleVisibility: .visible) {
            Button("已完成转账，记录结算") {
                guard let pendingBalance else { return }
                store.settle(expectedBalance: pendingBalance)
                self.pendingBalance = nil
                if store.isSettled { dismiss() }
            }
            Button("取消", role: .cancel) { pendingBalance = nil }
        } message: {
            if let balance = pendingBalance, let sender = balance.sender, let receiver = balance.receiver {
                Text("\(store.name(for: sender))给\(store.name(for: receiver)) \(balance.amountInCents.currency)。此操作仅记录结算，不会实际转账。")
            }
        }
    }
}

private func stat(_ title: String, _ cents: Int64) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
        Text(cents.currency).font(.caption.monospaced())
            .lineLimit(1).minimumScaleFactor(0.5)
    }.frame(maxWidth: .infinity, alignment: .leading)
}
private struct LedgerLine: View { let title: String; let detail: String; let amount: String; var body: some View { HStack { Image(systemName: "circle.grid.2x2").foregroundStyle(Theme.terra); VStack(alignment: .leading) { Text(title).font(.subheadline.bold()); Text(detail).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(amount).font(.caption.monospaced()) } .padding(.vertical, 12) } }
private struct SettingLine: View { let title: String; let detail: String; let icon: String; var body: some View { HStack { Image(systemName: icon).frame(width: 30); VStack(alignment: .leading) { Text(title).font(.subheadline); Text(detail).font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary) }.padding(.vertical, 8) } }
private extension Text { func eyebrow() -> some View { self.font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary) }; func sectionLabel() -> some View { self.font(.caption.weight(.semibold)).foregroundStyle(.secondary) }; func muted(font: Font = .caption) -> some View { self.font(font).foregroundStyle(.secondary) }; func avatar(_ background: Color, _ foreground: Color) -> some View { self.font(.caption.weight(.bold)).frame(width: 38, height: 38).background(background, in: Circle()).foregroundStyle(foreground).overlay(Circle().stroke(Theme.paper, lineWidth: 2)) } }
private extension Int64 {
    var currency: String {
        let magnitude = self.magnitude
        let fraction = magnitude % 100
        return "\(self < 0 ? "-" : "")¥\(magnitude / 100).\(fraction < 10 ? "0" : "")\(fraction)"
    }
}

#Preview("iPhone SE") { ContentView().environmentObject(LedgerStore.preview).previewDevice("iPhone SE (3rd generation)") }
#Preview("iPhone 15 Pro Max") { ContentView().environmentObject(LedgerStore.preview).previewDevice("iPhone 15 Pro Max") }
