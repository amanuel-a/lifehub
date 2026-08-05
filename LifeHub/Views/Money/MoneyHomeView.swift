//
//  MoneyHomeView.swift
//  LifeHub
//

import SwiftUI
import SwiftData

/// The Money tab: the full money picture at a glance, with entry points to
/// income, expenses, bills & rent, debts, loans, budgets, and reports.
struct MoneyHomeView: View {
    @Environment(\.modelContext) private var modelContext

    @Environment(\.currencyCode) private var appCurrency

    @State private var summary: MonthlySummary?
    @State private var debtTotals: (iOwe: [String: Decimal], owedToMe: [String: Decimal]) = ([:], [:])
    @State private var summaryPage = 0

    var body: some View {
        NavigationStack {
            List {
                Section {
                    monthOverview
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 4, trailing: 12))
                        .listRowBackground(Color.clear)
                }

                Section("Track") {
                    NavigationLink { JobsView() } label: {
                        MoneyRow("Jobs", systemImage: "briefcase.fill", tint: .indigo)
                    }
                    NavigationLink { IncomeSourcesView() } label: {
                        MoneyRow("Income & Salary", systemImage: "banknote.fill", tint: .green)
                    }
                    NavigationLink { ExpensesView() } label: {
                        MoneyRow("Expenses", systemImage: "cart.fill", tint: .orange)
                    }
                    NavigationLink { BillsView() } label: {
                        MoneyRow("Rent & Bills", systemImage: "house.fill", tint: .blue)
                    }
                    NavigationLink { DebtsView() } label: {
                        MoneyRow("Debts", systemImage: "person.2.fill", tint: .pink)
                    }
                    NavigationLink { LoansView() } label: {
                        MoneyRow("Loans", systemImage: "building.columns.fill", tint: .purple)
                    }
                }

                Section("Understand") {
                    NavigationLink { BudgetsView() } label: {
                        MoneyRow("Budgets", systemImage: "chart.pie.fill", tint: .teal)
                    }
                    NavigationLink { ReportsView() } label: {
                        MoneyRow("Reports & Monthly Review", systemImage: "chart.bar.fill", tint: .cyan)
                    }
                }
            }
            .navigationTitle("Money")
            .onAppear(perform: refresh)
        }
    }

    // MARK: Month overview — swipeable summary cards

    private var monthOverview: some View {
        let income = summary?.income ?? 0
        let expenses = summary?.expenses ?? 0
        let savings = income - expenses
        let savingsPositive = savings >= 0
        let spentFraction: Double = {
            guard income > 0 else { return expenses > 0 ? 1 : 0 }
            let value = NSDecimalNumber(decimal: expenses).doubleValue / NSDecimalNumber(decimal: income).doubleValue
            return min(max(value, 0), 1)
        }()

        let incomeDisplay = StatsService.display(of: summary?.incomeByCurrency ?? [:], appCurrency: appCurrency)
        let iOweDisplay = StatsService.display(of: debtTotals.iOwe, appCurrency: appCurrency)
        let owedToMeDisplay = StatsService.display(of: debtTotals.owedToMe, appCurrency: appCurrency)

        return TabView(selection: $summaryPage) {
            MoneySummaryCard(
                title: "This Month",
                systemImage: "wallet.bifold.fill",
                caption: savingsPositive ? "Saved" : "Overspent",
                amount: abs(savings),
                colors: savingsPositive ? [.green, .mint] : [.orange, .red],
                progress: spentFraction
            )
            .tag(0)

            MoneySummaryCard(
                title: "Income",
                systemImage: "arrow.down.circle.fill",
                caption: "Received this month",
                amount: incomeDisplay.amount,
                colors: [.green, .teal],
                extra: incomeDisplay.extra
            )
            .environment(\.currencyCode, incomeDisplay.code)
            .tag(1)

            MoneySummaryCard(
                title: "Expenses",
                systemImage: "cart.fill",
                caption: "Spent this month",
                amount: expenses,
                colors: [.orange, .red]
            )
            .tag(2)

            MoneySummaryCard(
                title: "I Owe",
                systemImage: "arrow.up.right.circle.fill",
                caption: "Outstanding",
                amount: iOweDisplay.amount,
                colors: [.pink, .purple],
                extra: iOweDisplay.extra
            )
            .environment(\.currencyCode, iOweDisplay.code)
            .tag(3)

            MoneySummaryCard(
                title: "Owed to Me",
                systemImage: "arrow.down.left.circle.fill",
                caption: "To collect",
                amount: owedToMeDisplay.amount,
                colors: [.teal, .blue],
                extra: owedToMeDisplay.extra
            )
            .environment(\.currencyCode, owedToMeDisplay.code)
            .tag(4)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        .frame(height: 190)
        .animation(.snappy, value: summaryPage)
    }

    private func refresh() {
        summary = StatsService.summary(forMonthContaining: .now, context: modelContext)
        debtTotals = StatsService.debtTotals(context: modelContext)
    }
}

/// A full-width gradient summary card used in the swipeable overview carousel.
struct MoneySummaryCard: View {
    let title: LocalizedStringKey
    let systemImage: String
    let caption: LocalizedStringKey
    let amount: Decimal
    let colors: [Color]
    /// 0...1 spent-vs-income bar, shown only on the "This Month" card.
    var progress: Double? = nil
    /// Extra line for other-currency buckets, e.g. "+ 100 USD".
    var extra: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 2) {
                Text(caption)
                    .font(.footnote.weight(.medium))
                    .opacity(0.85)
                AmountText(amount: amount)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let extra {
                    Text(extra)
                        .font(.footnote.weight(.semibold))
                        .opacity(0.9)
                        .lineLimit(1)
                }
            }

            if let progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.25))
                        Capsule().fill(.white).frame(width: max(6, geo.size.width * progress))
                    }
                }
                .frame(height: 8)
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: .rect(cornerRadius: 24)
        )
        .padding(.bottom, 28)
        .accessibilityElement(children: .combine)
    }
}

/// A navigation row with a Settings-style colored icon badge.
struct MoneyRow: View {
    let titleKey: LocalizedStringKey
    let systemImage: String
    let tint: Color

    init(_ titleKey: LocalizedStringKey, systemImage: String, tint: Color) {
        self.titleKey = titleKey
        self.systemImage = systemImage
        self.tint = tint
    }

    var body: some View {
        Label {
            Text(titleKey)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 29, height: 29)
                .background(tint.gradient, in: .rect(cornerRadius: 7))
        }
    }
}

#Preview {
    MoneyHomeView()
        .modelContainer(ModelContainerFactory.preview())
}

// MARK: - Jobs

/// A job-centric view of income sources: add where you work, when you started,
/// see automatically which day you're on and how long you've stayed, plus the
/// income you're set to earn and when the next payday lands.
struct JobsView: View {
    @Query(sort: \IncomeSource.createdAt) private var sources: [IncomeSource]

    @State private var showingForm = false

    private var currentJobs: [IncomeSource] {
        sources.filter(\.isActive)
    }

    private var pastJobs: [IncomeSource] {
        sources.filter { !$0.isActive }
    }

    var body: some View {
        List {
            if sources.isEmpty {
                EmptyStateView(
                    titleKey: "No Jobs Yet",
                    messageKey: "Add where you work with a start date — LifeHub counts your days automatically and tracks the income you'll earn.",
                    symbolName: "briefcase"
                )
                .listRowBackground(Color.clear)
            }

            if !currentJobs.isEmpty {
                Section("Current") {
                    ForEach(currentJobs) { job in
                        NavigationLink {
                            IncomeSourceDetailView(source: job)
                        } label: {
                            JobCard(job: job)
                        }
                    }
                }
            }

            if !pastJobs.isEmpty {
                Section("Past Jobs") {
                    ForEach(pastJobs) { job in
                        NavigationLink {
                            IncomeSourceDetailView(source: job)
                        } label: {
                            JobCard(job: job)
                        }
                    }
                }
            }
        }
        .navigationTitle("Jobs")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingForm = true
                } label: {
                    Label("Add Job", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingForm) {
            IncomeSourceFormView()
        }
    }
}

/// A rich card for one job: the day you're on, tenure, start date, and the
/// income you'll earn with the next payday countdown.
struct JobCard: View {
    @Environment(\.currencyCode) private var appCurrency
    let job: IncomeSource

    private var accent: Color { job.isActive ? .green : .gray }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                SymbolBadge(symbolName: job.type.symbolName, color: accent, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(job.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(job.type.titleKey)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    AmountText(amount: job.amount, compact: true)
                        .font(.headline)
                        .environment(\.currencyCode, job.currencyCode ?? appCurrency)
                    Text(job.frequency.titleKey)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if job.dayNumber != nil || job.startDate != nil {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        if let day = job.dayNumber {
                            Text("Day \(day)")
                                .font(.title3.weight(.bold))
                                .fontDesign(.rounded)
                                .foregroundStyle(accent)
                                .contentTransition(.numericText())
                        }
                        if let tenure = job.tenureDescription {
                            Text(tenure)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if job.isActive, let next = job.nextPayday() {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Next Pay")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            Text(next.isToday ? String(localized: "Today 🎉") : next.relativeDayDescription)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(next.daysFromToday <= 1 ? .green : .primary)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(accent.opacity(0.12), in: .rect(cornerRadius: 12))
            }

            if let started = job.startDate {
                Label {
                    Text("Started \(started, format: .dateTime.month(.wide).day().year())")
                } icon: {
                    Image(systemName: "calendar")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
