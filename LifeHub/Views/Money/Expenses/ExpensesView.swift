//
//  ExpensesView.swift
//  LifeHub
//

import SwiftUI
import SwiftData

/// The expense log, month by month: totals header, grouped by day,
/// swipe to delete, and one-tap add.
struct ExpensesView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var month = Date.now
    @State private var showingForm = false
    @State private var editingExpense: Expense?
    @Query(sort: \Expense.date, order: .reverse) private var allExpenses: [Expense]

    private var calendar: Calendar { .current }

    private var monthExpenses: [Expense] {
        let interval = StatsService.monthInterval(containing: month)
        return allExpenses.filter { interval.contains($0.date) }
    }

    private var monthTotal: Decimal {
        monthExpenses.reduce(Decimal.zero) { $0 + $1.amount }
    }

    /// Expenses grouped by day, newest day first.
    private var groupedByDay: [(day: Date, items: [Expense])] {
        let groups = Dictionary(grouping: monthExpenses) { calendar.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { ($0, groups[$0] ?? []) }
    }

    var body: some View {
        List {
            Section {
                MonthSwitcher(month: $month)
                HStack {
                    Text("Total spent")
                        .foregroundStyle(.secondary)
                    Spacer()
                    AmountText(amount: monthTotal)
                        .font(.headline)
                }
            }

            if monthExpenses.isEmpty {
                EmptyStateView(
                    titleKey: "No Expenses",
                    messageKey: "Tap + to log an expense in seconds.",
                    symbolName: "cart"
                )
                .listRowBackground(Color.clear)
            }

            ForEach(groupedByDay, id: \.day) { group in
                Section {
                    ForEach(group.items) { expense in
                        ExpenseRow(expense: expense)
                            .contentShape(.rect)
                            .onTapGesture { editingExpense = expense }
                    }
                    .onDelete { offsets in
                        delete(offsets.map { group.items[$0] })
                    }
                } header: {
                    Text(group.day, format: .dateTime.weekday(.wide).day().month())
                }
            }
        }
        .navigationTitle("Expenses")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingForm = true
                } label: {
                    Label("Add Expense", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingForm) {
            ExpenseFormView()
        }
        .sheet(item: $editingExpense) { expense in
            ExpenseFormView(expense: expense)
        }
    }

    private func delete(_ expenses: [Expense]) {
        for expense in expenses {
            modelContext.delete(expense)
        }
        try? modelContext.save()
        SnapshotService.refresh(context: modelContext)
    }
}

/// One expense row with category badge, note, and amount.
struct ExpenseRow: View {
    let expense: Expense

    var body: some View {
        HStack(spacing: 12) {
            SymbolBadge(
                symbolName: expense.category?.symbolName ?? "questionmark",
                color: Color(hex: expense.category?.colorHex ?? "#9CA3AF")
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.category?.name ?? String(localized: "Uncategorized"))
                    .font(.body.weight(.medium))
                if !expense.note.isEmpty {
                    Text(expense.note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                AmountText(amount: expense.amount)
                    .font(.subheadline.weight(.semibold))
                if expense.receiptImageData != nil {
                    Image(systemName: "paperclip")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(Text("Has receipt photo"))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Compact month navigation used by expenses and reports.
struct MonthSwitcher: View {
    @Binding var month: Date

    var body: some View {
        HStack {
            Button {
                shift(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel(Text("Previous month"))

            Spacer()
            Text(month, format: .dateTime.month(.wide).year())
                .font(.headline)
                .contentTransition(.numericText())
            Spacer()

            Button {
                shift(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel(Text("Next month"))
            .disabled(Calendar.current.isDate(month, equalTo: .now, toGranularity: .month))
        }
        .buttonStyle(.borderless)
    }

    private func shift(by value: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: value, to: month) {
            withAnimation(.spring(duration: 0.3)) { month = next }
        }
    }
}
