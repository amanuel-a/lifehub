//
//  LoansView.swift
//  LifeHub
//

import SwiftUI
import SwiftData

/// Bank / formal loans with installment schedules and remaining balances.
struct LoansView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Loan.createdAt, order: .reverse) private var loans: [Loan]

    @State private var showingForm = false

    private var openLoans: [Loan] { loans.filter { !$0.isClosed } }
    private var closedLoans: [Loan] { loans.filter(\.isClosed) }

    private var totalRemaining: Decimal {
        openLoans.reduce(Decimal.zero) { $0 + $1.remainingBalance }
    }

    var body: some View {
        List {
            if !openLoans.isEmpty {
                Section {
                    StatCard(
                        titleKey: "Total Remaining",
                        amount: totalRemaining,
                        symbolName: "building.columns.fill",
                        tint: .purple
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }
            }

            if loans.isEmpty {
                EmptyStateView(
                    titleKey: "No Loans",
                    messageKey: "Track bank loans with installment reminders and remaining balances.",
                    symbolName: "building.columns"
                )
                .listRowBackground(Color.clear)
            }

            if !openLoans.isEmpty {
                Section("Active") {
                    ForEach(openLoans) { loan in
                        NavigationLink {
                            LoanDetailView(loan: loan)
                        } label: {
                            LoanRow(loan: loan)
                        }
                    }
                }
            }

            if !closedLoans.isEmpty {
                Section("Paid Off") {
                    ForEach(closedLoans) { loan in
                        NavigationLink {
                            LoanDetailView(loan: loan)
                        } label: {
                            LoanRow(loan: loan)
                        }
                    }
                }
            }
        }
        .navigationTitle("Loans")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingForm = true
                } label: {
                    Label("Add Loan", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingForm) {
            LoanFormView()
        }
    }
}

/// One loan row: lender, progress, next installment.
struct LoanRow: View {
    let loan: Loan

    var body: some View {
        HStack(spacing: 12) {
            SymbolBadge(symbolName: "building.columns.fill", color: loan.isClosed ? .gray : .purple)
            VStack(alignment: .leading, spacing: 4) {
                Text(loan.lender)
                    .font(.body.weight(.medium))
                if !loan.isClosed {
                    ProgressView(value: loan.progress)
                        .tint(.purple)
                        .scaleEffect(y: 0.8)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                AmountText(amount: loan.remainingBalance, compact: true)
                    .font(.subheadline.weight(.semibold))
                if loan.isClosed {
                    Text("Paid off")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Text(loan.nextDueDate.relativeDayDescription)
                        .font(.caption)
                        .foregroundStyle(loan.nextDueDate.daysFromToday <= 3 ? .orange : .secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
