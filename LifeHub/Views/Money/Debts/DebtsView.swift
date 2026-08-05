//
//  DebtsView.swift
//  LifeHub
//

import SwiftUI
import SwiftData

/// The debts overview: totals for both directions at a glance, what's due
/// soon, and the full list split "I owe" / "Owed to me".
struct DebtsView: View {
    @Environment(\.modelContext) private var modelContext

    @Environment(\.currencyCode) private var appCurrency

    @Query(sort: \Debt.createdAt, order: .reverse) private var debts: [Debt]

    @State private var showingForm = false
    @State private var showSettled = false

    /// Sums debts into per-currency buckets — amounts stay as entered.
    private func totals(_ list: [Debt]) -> [String: Decimal] {
        var buckets: [String: Decimal] = [:]
        for debt in list {
            buckets[debt.currencyCode ?? appCurrency, default: .zero] += debt.remaining
        }
        return buckets
    }

    private var openDebts: [Debt] {
        debts.filter { !$0.isSettled && $0.remaining > 0 }
    }

    private var iOweDebts: [Debt] {
        openDebts.filter { $0.direction == .iOwe }
    }

    private var owedToMeDebts: [Debt] {
        openDebts.filter { $0.direction == .owedToMe }
    }

    private var settledDebts: [Debt] {
        debts.filter { $0.isSettled || $0.remaining == 0 }
    }

    private var iOweDisplay: StatsService.TotalDisplay {
        StatsService.display(of: totals(iOweDebts), appCurrency: appCurrency)
    }

    private var owedToMeDisplay: StatsService.TotalDisplay {
        StatsService.display(of: totals(owedToMeDebts), appCurrency: appCurrency)
    }

    private var dueSoon: [Debt] {
        openDebts
            .filter { ($0.dueDate?.daysFromToday ?? .max) <= 7 }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    StatCard(titleKey: "I Owe", amount: iOweDisplay.amount, symbolName: "arrow.up.right.circle.fill", tint: .pink, extraText: iOweDisplay.extra)
                        .environment(\.currencyCode, iOweDisplay.code)
                    StatCard(titleKey: "Owed to Me", amount: owedToMeDisplay.amount, symbolName: "arrow.down.left.circle.fill", tint: .teal, extraText: owedToMeDisplay.extra)
                        .environment(\.currencyCode, owedToMeDisplay.code)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }

            if !dueSoon.isEmpty {
                Section("Due Soon") {
                    ForEach(dueSoon) { debt in
                        debtLink(debt)
                    }
                }
            }

            if openDebts.isEmpty && settledDebts.isEmpty {
                EmptyStateView(
                    titleKey: "No Debts",
                    messageKey: "Track money you owe people and money owed to you, with partial repayments.",
                    symbolName: "person.2"
                )
                .listRowBackground(Color.clear)
            }

            if !iOweDebts.isEmpty {
                Section("I Owe") {
                    ForEach(iOweDebts) { debt in
                        debtLink(debt)
                    }
                }
            }

            if !owedToMeDebts.isEmpty {
                Section("Owed to Me") {
                    ForEach(owedToMeDebts) { debt in
                        debtLink(debt)
                    }
                }
            }

            if !settledDebts.isEmpty {
                Section {
                    DisclosureGroup("Settled (\(settledDebts.count))", isExpanded: $showSettled) {
                        ForEach(settledDebts) { debt in
                            debtLink(debt)
                        }
                    }
                }
            }
        }
        .navigationTitle("Debts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingForm = true
                } label: {
                    Label("Add Debt", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingForm) {
            DebtFormView()
        }
    }

    private func debtLink(_ debt: Debt) -> some View {
        NavigationLink {
            DebtDetailView(debt: debt)
        } label: {
            DebtRow(debt: debt)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                modelContext.delete(debt)
                try? modelContext.save()
                NotificationScheduler.refreshAll(context: modelContext)
                SnapshotService.refresh(context: modelContext)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

/// One debt row: person, direction, remaining balance, due date.
struct DebtRow: View {
    @Environment(\.currencyCode) private var appCurrency
    let debt: Debt

    var body: some View {
        HStack(spacing: 12) {
            SymbolBadge(
                symbolName: debt.direction == .iOwe ? "arrow.up.right" : "arrow.down.left",
                color: debt.isSettled ? .gray : (debt.direction == .iOwe ? .pink : .teal)
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(debt.person)
                    .font(.body.weight(.medium))
                if debt.totalRepaid > 0 && !debt.isSettled {
                    Text("Repaid \(MoneyFormat.compactString(debt.totalRepaid, code: ""))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                AmountText(amount: debt.isSettled ? debt.originalAmount : debt.remaining, compact: true)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(debt.isSettled ? .secondary : .primary)
                    .environment(\.currencyCode, debt.currencyCode ?? appCurrency)
                if let due = debt.dueDate, !debt.isSettled {
                    Text(due.relativeDayDescription)
                        .font(.caption)
                        .foregroundStyle(due.daysFromToday <= 3 ? .orange : .secondary)
                } else if debt.isSettled {
                    Text("Settled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
