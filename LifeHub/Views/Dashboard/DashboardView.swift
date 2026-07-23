//
//  DashboardView.swift
//  LifeHub
//

import SwiftUI
import SwiftData

/// The home screen: today at a glance, money at a glance, next payday per
/// job with countdowns, upcoming reminders with quick actions, and
/// one-tap quick-add buttons.
struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router

    @Query(sort: \IncomeSource.createdAt) private var sources: [IncomeSource]
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    @State private var todayItems: [AgendaItem] = []
    @State private var upcomingItems: [AgendaItem] = []
    @State private var summary: MonthlySummary?
    @State private var debtTotals: (iOwe: Decimal, owedToMe: Decimal) = (0, 0)
    @State private var showingSettings = false

    private var activeSources: [IncomeSource] {
        sources.filter(\.isActive)
    }

    var body: some View {
        NavigationStack {
            List {
                quickAddSection
                todaySection
                moneySection
                paydaySection
                upcomingSection
            }
            .navigationTitle("LifeHub")
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

    // MARK: Quick add

    private var quickAddSection: some View {
        Section {
            HStack(spacing: 10) {
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
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowBackground(Color.clear)
        }
    }

    // MARK: Today

    private var todaySection: some View {
        Section("Today") {
            if todayItems.isEmpty {
                Label {
                    Text("Nothing due today. Enjoy!")
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "sun.max.fill")
                        .foregroundStyle(.yellow)
                }
            } else {
                ForEach(todayItems) { item in
                    AgendaRow(item: item)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            quickAction(for: item)
                        }
                        .contextMenu {
                            quickAction(for: item)
                        }
                }
            }
        }
    }

    // MARK: Money

    private var moneySection: some View {
        Section("This Month") {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    StatCard(titleKey: "Income", amount: summary?.income ?? 0, symbolName: "arrow.down.circle.fill", tint: .green)
                    StatCard(titleKey: "Spent", amount: summary?.expenses ?? 0, symbolName: "arrow.up.circle.fill", tint: .orange)
                }
                HStack(spacing: 10) {
                    StatCard(titleKey: "I Owe", amount: debtTotals.iOwe, symbolName: "arrow.up.right.circle.fill", tint: .pink)
                    StatCard(titleKey: "Owed to Me", amount: debtTotals.owedToMe, symbolName: "arrow.down.left.circle.fill", tint: .teal)
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
        }
    }

    // MARK: Paydays

    @ViewBuilder
    private var paydaySection: some View {
        if !activeSources.isEmpty {
            Section("Next Paydays") {
                ForEach(activeSources) { source in
                    if let next = source.nextPayday() {
                        HStack(spacing: 12) {
                            SymbolBadge(symbolName: source.type.symbolName, color: .green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.name)
                                    .font(.body.weight(.medium))
                                Text(next, format: .dateTime.weekday(.wide).day().month())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(next.isToday ? String(localized: "Today 🎉") : next.relativeDayDescription)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(next.daysFromToday <= 1 ? .green : .secondary)
                                .contentTransition(.numericText())
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    // MARK: Upcoming

    private var upcomingSection: some View {
        Section("Upcoming") {
            if upcomingItems.isEmpty {
                Text("Nothing coming up in the next 7 days.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(upcomingItems.prefix(8)) { item in
                    AgendaRow(item: item, showsDate: true)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            quickAction(for: item)
                        }
                        .contextMenu {
                            quickAction(for: item)
                        }
                }
            }
        }
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
            .tint(.green)
        case .rent, .bill:
            Button {
                markBillPaid(item)
            } label: {
                Label("Mark Paid", systemImage: "checkmark.circle.fill")
            }
            .tint(.green)
        case .payday:
            Button {
                confirmPayday(item)
            } label: {
                Label("Money Arrived", systemImage: "checkmark.circle.fill")
            }
            .tint(.green)
        case .loan:
            Button {
                recordLoanPayment(item)
            } label: {
                Label("Mark Paid", systemImage: "checkmark.circle.fill")
            }
            .tint(.green)
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
            VStack(spacing: 6) {
                Image(systemName: symbolName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(tint.gradient, in: .circle)
                Text(titleKey)
                    .font(.caption2.weight(.medium))
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
