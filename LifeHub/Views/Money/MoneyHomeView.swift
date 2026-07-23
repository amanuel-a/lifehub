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

    @State private var summary: MonthlySummary?
    @State private var debtTotals: (iOwe: Decimal, owedToMe: Decimal) = (0, 0)

    var body: some View {
        NavigationStack {
            List {
                Section {
                    monthOverview
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                }

                Section("Track") {
                    NavigationLink {
                        IncomeSourcesView()
                    } label: {
                        Label("Income & Salary", systemImage: "banknote.fill")
                            .foregroundStyle(.primary)
                    }
                    NavigationLink {
                        ExpensesView()
                    } label: {
                        Label("Expenses", systemImage: "cart.fill")
                            .foregroundStyle(.primary)
                    }
                    NavigationLink {
                        BillsView()
                    } label: {
                        Label("Rent & Bills", systemImage: "house.fill")
                            .foregroundStyle(.primary)
                    }
                    NavigationLink {
                        DebtsView()
                    } label: {
                        Label("Debts", systemImage: "person.2.fill")
                            .foregroundStyle(.primary)
                    }
                    NavigationLink {
                        LoansView()
                    } label: {
                        Label("Loans", systemImage: "building.columns.fill")
                            .foregroundStyle(.primary)
                    }
                }

                Section("Understand") {
                    NavigationLink {
                        BudgetsView()
                    } label: {
                        Label("Budgets", systemImage: "chart.pie.fill")
                            .foregroundStyle(.primary)
                    }
                    NavigationLink {
                        ReportsView()
                    } label: {
                        Label("Reports & Monthly Review", systemImage: "chart.bar.fill")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Money")
            .onAppear(perform: refresh)
        }
    }

    private var monthOverview: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                StatCard(
                    titleKey: "Income",
                    amount: summary?.income ?? 0,
                    symbolName: "arrow.down.circle.fill",
                    tint: .green
                )
                StatCard(
                    titleKey: "Expenses",
                    amount: summary?.expenses ?? 0,
                    symbolName: "arrow.up.circle.fill",
                    tint: .orange
                )
                StatCard(
                    titleKey: "Savings",
                    amount: summary?.savings ?? 0,
                    symbolName: "leaf.fill",
                    tint: .mint
                )
            }
            HStack(spacing: 10) {
                StatCard(
                    titleKey: "I Owe",
                    amount: debtTotals.iOwe,
                    symbolName: "arrow.up.right.circle.fill",
                    tint: .pink
                )
                StatCard(
                    titleKey: "Owed to Me",
                    amount: debtTotals.owedToMe,
                    symbolName: "arrow.down.left.circle.fill",
                    tint: .teal
                )
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func refresh() {
        summary = StatsService.summary(forMonthContaining: .now, context: modelContext)
        debtTotals = StatsService.debtTotals(context: modelContext)
    }
}

#Preview {
    MoneyHomeView()
        .modelContainer(ModelContainerFactory.preview())
}
