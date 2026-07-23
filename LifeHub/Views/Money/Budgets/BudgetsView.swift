//
//  BudgetsView.swift
//  LifeHub
//

import SwiftUI
import SwiftData

/// Simple per-category monthly budgets with usage bars and warnings when
/// spending approaches the limit.
struct BudgetsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    @State private var summary: MonthlySummary?
    @State private var editingCategory: ExpenseCategory?

    var body: some View {
        List {
            Section {
                Text("Set a monthly limit per category. LifeHub warns you as spending approaches it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }

            Section("This Month") {
                ForEach(categories) { category in
                    Button {
                        editingCategory = category
                    } label: {
                        BudgetRow(category: category, spent: spent(for: category))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Budgets")
        .onAppear {
            summary = StatsService.summary(forMonthContaining: .now, context: modelContext)
        }
        .sheet(item: $editingCategory) { category in
            BudgetEditSheet(category: category)
                .onDisappear {
                    summary = StatsService.summary(forMonthContaining: .now, context: modelContext)
                }
        }
    }

    private func spent(for category: ExpenseCategory) -> Decimal {
        summary?.categoryTotals.first { $0.id == category.uuid }?.total ?? 0
    }
}

/// One category's budget state: spent vs. limit with a tinted usage bar.
struct BudgetRow: View {
    @Environment(\.currencyCode) private var currencyCode

    let category: ExpenseCategory
    let spent: Decimal

    private var usage: Double? {
        guard let budget = category.monthlyBudget, budget > 0 else { return nil }
        return NSDecimalNumber(decimal: spent).doubleValue / NSDecimalNumber(decimal: budget).doubleValue
    }

    private var barTint: Color {
        guard let usage else { return .secondary }
        if usage >= 1 { return .red }
        if usage >= 0.8 { return .orange }
        return Color(hex: category.colorHex)
    }

    var body: some View {
        HStack(spacing: 12) {
            SymbolBadge(symbolName: category.symbolName, color: Color(hex: category.colorHex))
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(category.name)
                        .font(.body.weight(.medium))
                    Spacer()
                    if let budget = category.monthlyBudget {
                        Text("\(MoneyFormat.compactString(spent, code: "")) / \(MoneyFormat.string(budget, code: currencyCode))")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No budget")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                if let usage {
                    ProgressView(value: min(usage, 1))
                        .tint(barTint)
                    if usage >= 0.8 {
                        Label(
                            usage >= 1 ? "Over budget" : "Approaching limit",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(usage >= 1 ? .red : .orange)
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// Sets or clears a category's monthly budget.
struct BudgetEditSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var category: ExpenseCategory

    @State private var budgetText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CurrencyField(titleKey: "Monthly limit", text: $budgetText)
                } header: {
                    Text(category.name)
                } footer: {
                    Text("Leave empty to remove the budget.")
                }
            }
            .navigationTitle("Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        category.monthlyBudget = Decimal.fromUserInput(budgetText)
                        try? modelContext.save()
                        Haptics.shared.success()
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let budget = category.monthlyBudget {
                    budgetText = "\(budget)"
                }
            }
        }
        .presentationDetents([.medium])
    }
}
