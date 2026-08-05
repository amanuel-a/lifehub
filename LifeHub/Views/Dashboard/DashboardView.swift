//
//  DashboardView.swift
//  LifeHub
//

import SwiftUI
import SwiftData

/// The home screen: a warm greeting, this month's balance at a glance, one-tap
/// quick-add actions, a money overview grid, next payday countdowns, and
/// today's / upcoming reminders — styled like a first-party Apple app.
struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.currencyCode) private var appCurrency
    @Environment(AppRouter.self) private var router

    @Query(sort: \IncomeSource.createdAt) private var sources: [IncomeSource]
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    @State private var todayItems: [AgendaItem] = []
    @State private var upcomingItems: [AgendaItem] = []
    @State private var summary: MonthlySummary?
    @State private var debtTotals: (iOwe: [String: Decimal], owedToMe: [String: Decimal]) = ([:], [:])
    @State private var showingSettings = false

    private let cardFill = Color(.secondarySystemGroupedBackground)

    private var activeSources: [IncomeSource] {
        sources.filter(\.isActive)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    greetingHeader
                    balanceCard
                    quickAddCard
                    overviewSection
                    paydaySection
                    todaySection
                    upcomingSection
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showingSettings, onDismiss: refresh) {
                SettingsView()
            }
            .onAppear(perform: refresh)
            .refreshable { refresh() }
        }
    }

    // MARK: Greeting header

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date.now, format: .dateTime.weekday(.wide).month().day())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(greeting)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var greeting: LocalizedStringKey {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        case 17..<22: "Good evening"
        default: "Good night"
        }
    }

    // MARK: Balance hero card

    private var balanceCard: some View {
        let income = summary?.income ?? 0
        let spent = summary?.expenses ?? 0
        let savings = income - spent
        let positive = savings >= 0
        let fraction: Double = {
            guard income > 0 else { return spent > 0 ? 1 : 0 }
            let value = NSDecimalNumber(decimal: spent).doubleValue / NSDecimalNumber(decimal: income).doubleValue
            return min(max(value, 0), 1)
        }()
        let colors: [Color] = positive ? [.green, .mint] : [.orange, .red]

        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("This Month", systemImage: "wallet.bifold.fill")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(summary?.month ?? .now, format: .dateTime.month(.wide))
                    .font(.subheadline.weight(.semibold))
                    .opacity(0.85)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(positive ? "Saved" : "Overspent")
                    .font(.footnote.weight(.medium))
                    .opacity(0.85)
                AmountText(amount: abs(savings))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
            }

            VStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.25))
                        Capsule()
                            .fill(.white)
                            .frame(width: max(6, geo.size.width * fraction))
                    }
                }
                .frame(height: 8)

                HStack {
                    balanceMetric(label: "Income", amount: income)
                    Spacer()
                    balanceMetric(label: "Spent", amount: spent, trailing: true)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: .rect(cornerRadius: 26)
        )
        .shadow(color: colors.first!.opacity(0.35), radius: 16, x: 0, y: 8)
        .accessibilityElement(children: .combine)
    }

    private func balanceMetric(label: LocalizedStringKey, amount: Decimal, trailing: Bool = false) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 1) {
            Text(label)
                .font(.caption2.weight(.medium))
                .opacity(0.85)
            AmountText(amount: amount, compact: true)
                .font(.subheadline.weight(.bold))
        }
    }

    // MARK: Quick add

    private var quickAddCard: some View {
        HStack(spacing: 6) {
            QuickAddButton(titleKey: "Expense", symbolName: "cart.fill.badge.plus", tint: .orange) {
                router.pendingQuickAdd = .expense
            }
            QuickAddButton(titleKey: "Income", symbolName: "banknote.fill", tint: .green) {
                router.pendingQuickAdd = .income
            }
            QuickAddButton(titleKey: "Task", symbolName: "checkmark.circle.fill", tint: .indigo) {
                router.pendingQuickAdd = .task
            }
            QuickAddButton(titleKey: "Note", symbolName: "square.and.pencil", tint: .yellow) {
                router.pendingQuickAdd = .note
            }
            QuickAddButton(titleKey: "Event", symbolName: "calendar.badge.plus", tint: .blue) {
                router.pendingQuickAdd = .event
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .background(cardFill, in: .rect(cornerRadius: 20))
    }

    // MARK: Money overview grid

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Overview", systemImage: "chart.pie.fill", tint: .teal)
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    let income = StatsService.display(of: summary?.incomeByCurrency ?? [:], appCurrency: appCurrency)
                    StatCard(titleKey: "Income", amount: income.amount, symbolName: "arrow.down.circle.fill", tint: .green, extraText: income.extra)
                        .environment(\.currencyCode, income.code)
                    StatCard(titleKey: "Spent", amount: summary?.expenses ?? 0, symbolName: "arrow.up.circle.fill", tint: .orange)
                }
                HStack(spacing: 12) {
                    let iOwe = StatsService.display(of: debtTotals.iOwe, appCurrency: appCurrency)
                    let owedToMe = StatsService.display(of: debtTotals.owedToMe, appCurrency: appCurrency)
                    StatCard(titleKey: "I Owe", amount: iOwe.amount, symbolName: "arrow.up.right.circle.fill", tint: .pink, extraText: iOwe.extra)
                        .environment(\.currencyCode, iOwe.code)
                    StatCard(titleKey: "Owed to Me", amount: owedToMe.amount, symbolName: "arrow.down.left.circle.fill", tint: .teal, extraText: owedToMe.extra)
                        .environment(\.currencyCode, owedToMe.code)
                }
            }
        }
    }

    // MARK: Paydays

    @ViewBuilder
    private var paydaySection: some View {
        let upcoming = activeSources.compactMap { source -> (IncomeSource, Date)? in
            guard let next = source.nextPayday() else { return nil }
            return (source, next)
        }
        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Next Paydays", systemImage: "banknote.fill", tint: .green)
                VStack(spacing: 0) {
                    ForEach(Array(upcoming.enumerated()), id: \.element.0.id) { index, pair in
                        paydayRow(source: pair.0, next: pair.1)
                        if index < upcoming.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .background(cardFill, in: .rect(cornerRadius: 20))
            }
        }
    }

    private func paydayRow(source: IncomeSource, next: Date) -> some View {
        let imminent = next.daysFromToday <= 1
        return HStack(spacing: 14) {
            SymbolBadge(symbolName: source.type.symbolName, color: .green, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(next, format: .dateTime.weekday(.wide).day().month())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(next.isToday ? String(localized: "Today 🎉") : next.relativeDayDescription)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(imminent ? .green : .secondary)
                .contentTransition(.numericText())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background((imminent ? Color.green : Color.secondary).opacity(0.14), in: .capsule)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    // MARK: Today

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Today", systemImage: "sun.max.fill", tint: .orange)
            if todayItems.isEmpty {
                emptyCard(symbol: "checkmark.seal.fill", tint: .green, message: "Nothing due today. Enjoy!")
            } else {
                agendaCard(items: todayItems, showsDate: false)
            }
        }
    }

    // MARK: Upcoming

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Upcoming", systemImage: "calendar", tint: .blue)
            if upcomingItems.isEmpty {
                emptyCard(symbol: "sparkles", tint: .blue, message: "Nothing coming up in the next 7 days.")
            } else {
                agendaCard(items: Array(upcomingItems.prefix(8)), showsDate: true)
            }
        }
    }

    // MARK: Shared building blocks

    private func sectionHeader(_ title: LocalizedStringKey, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
            Text(title)
                .font(.title3.weight(.bold))
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func agendaCard(items: [AgendaItem], showsDate: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                AgendaRow(item: item, showsDate: showsDate)
                    .padding(.vertical, 10)
                    .contentShape(.rect)
                    .contextMenu { quickAction(for: item) }
                if index < items.count - 1 {
                    Divider().padding(.leading, 44)
                }
            }
        }
        .padding(.horizontal, 16)
        .background(cardFill, in: .rect(cornerRadius: 20))
    }

    private func emptyCard(symbol: String, tint: Color, message: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardFill, in: .rect(cornerRadius: 20))
    }

    // MARK: Quick actions on agenda items ("mark done / mark paid")

    @ViewBuilder
    private func quickAction(for item: AgendaItem) -> some View {
        switch item.kind {
        case .task:
            Button {
                markTaskDone(item)
            } label: {
                Label("Mark Done", systemImage: "checkmark.circle.fill")
            }
        case .rent, .bill:
            Button {
                markBillPaid(item)
            } label: {
                Label("Mark Paid", systemImage: "checkmark.circle.fill")
            }
        case .payday:
            Button {
                confirmPayday(item)
            } label: {
                Label("Money Arrived", systemImage: "checkmark.circle.fill")
            }
        case .loan:
            Button {
                recordLoanPayment(item)
            } label: {
                Label("Mark Paid", systemImage: "checkmark.circle.fill")
            }
        default:
            EmptyView()
        }
    }

    private func markTaskDone(_ item: AgendaItem) {
        guard let uuid = item.recordUUID,
              let task = fetchFirst(TaskItem.self, where: #Predicate { $0.uuid == uuid }) else { return }
        task.complete()
        Haptics.shared.success()
        persistAndRefresh()
    }

    private func markBillPaid(_ item: AgendaItem) {
        guard let uuid = item.recordUUID,
              let bill = fetchFirst(RecurringBill.self, where: #Predicate { $0.uuid == uuid }) else { return }
        let categoryName = bill.isRent ? "Rent" : "Utilities"
        let category = categories.first { $0.name.caseInsensitiveCompare(categoryName) == .orderedSame }
        let expense = bill.markPaid(category: category)
        modelContext.insert(expense)
        Haptics.shared.moneyConfirmed()
        persistAndRefresh()
    }

    private func confirmPayday(_ item: AgendaItem) {
        guard let uuid = item.recordUUID,
              let source = fetchFirst(IncomeSource.self, where: #Predicate { $0.uuid == uuid }) else { return }
        let entry = IncomeEntry(amount: source.amount, dateReceived: item.date, source: source)
        modelContext.insert(entry)
        Haptics.shared.moneyConfirmed()
        persistAndRefresh()
    }

    private func recordLoanPayment(_ item: AgendaItem) {
        guard let uuid = item.recordUUID,
              let loan = fetchFirst(Loan.self, where: #Predicate { $0.uuid == uuid }) else { return }
        loan.recordInstallment()
        Haptics.shared.moneyConfirmed()
        persistAndRefresh()
    }

    private func fetchFirst<T: PersistentModel>(_ type: T.Type, where predicate: Predicate<T>) -> T? {
        var descriptor = FetchDescriptor<T>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func persistAndRefresh() {
        try? modelContext.save()
        NotificationScheduler.refreshAll(context: modelContext)
        SnapshotService.refresh(context: modelContext)
        refresh()
    }

    private func refresh() {
        let calendar = Calendar.current
        todayItems = AgendaService.items(on: .now, context: modelContext)
        let tomorrow = calendar.startOfDay(for: .now).addingTimeInterval(86_400)
        if let weekEnd = calendar.date(byAdding: .day, value: 7, to: tomorrow) {
            upcomingItems = AgendaService.items(in: DateInterval(start: tomorrow, end: weekEnd), context: modelContext)
        }
        summary = StatsService.summary(forMonthContaining: .now, context: modelContext)
        debtTotals = StatsService.debtTotals(context: modelContext)
    }
}

/// One of the five one-tap quick-add buttons.
struct QuickAddButton: View {
    let titleKey: LocalizedStringKey
    let symbolName: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.shared.tap()
            action()
        } label: {
            VStack(spacing: 7) {
                Image(systemName: symbolName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(tint.gradient, in: .circle)
                    .shadow(color: tint.opacity(0.35), radius: 5, x: 0, y: 3)
                Text(titleKey)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(titleKey))
    }
}

#Preview {
    DashboardView()
        .modelContainer(ModelContainerFactory.preview())
        .environment(AppRouter.shared)
}
