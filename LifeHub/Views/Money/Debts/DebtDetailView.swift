//
//  DebtDetailView.swift
//  LifeHub
//

import SwiftUI
import SwiftData

/// One debt: remaining balance after partial repayments, repayment history,
/// and a quick "add repayment" flow.
struct DebtDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var debt: Debt

    @State private var showingEdit = false
    @State private var showingRepayment = false
    @State private var showingDeleteConfirm = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        SymbolBadge(
                            symbolName: debt.direction == .iOwe ? "arrow.up.right" : "arrow.down.left",
                            color: debt.direction == .iOwe ? .pink : .teal,
                            size: 44
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            AmountText(amount: debt.remaining)
                                .font(.title2.weight(.bold))
                            Text(debt.direction == .iOwe ? "You owe \(debt.person)" : "\(debt.person) owes you")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if debt.totalRepaid > 0 {
                        ProgressView(value: progressValue) {
                            HStack {
                                Text("Repaid")
                                Spacer()
                                AmountText(amount: debt.totalRepaid)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .tint(debt.direction == .iOwe ? .pink : .teal)
                    }
                    HStack(spacing: 4) {
                        Text("Original:")
                        AmountText(amount: debt.originalAmount)
                        Text("·")
                        Text(debt.date, format: .dateTime.day().month().year())
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    if let due = debt.dueDate {
                        Label {
                            Text("Due \(due.relativeDayDescription.lowercased()) — \(due, format: .dateTime.day().month().year())")
                        } icon: {
                            Image(systemName: "bell.badge.fill")
                                .foregroundStyle(.orange)
                        }
                        .font(.subheadline)
                    }
                    if !debt.note.isEmpty {
                        Text(debt.note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            if !debt.isFullyRepaid {
                Section {
                    Button {
                        showingRepayment = true
                    } label: {
                        Label("Add Repayment", systemImage: "plus.circle.fill")
                            .font(.body.weight(.semibold))
                    }
                }
            }

            Section("Repayments") {
                let repayments = debt.sortedRepayments
                if repayments.isEmpty {
                    Text("Partial payments appear here — the balance updates automatically.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(repayments, id: \.uuid) { payment in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                AmountText(amount: payment.amount)
                                    .font(.body.weight(.medium))
                                if !payment.note.isEmpty {
                                    Text(payment.note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(payment.date, format: .dateTime.day().month().year())
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(debt.person)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingEdit = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            DebtFormView(debt: debt)
        }
        .sheet(isPresented: $showingRepayment) {
            RepaymentSheet(debt: debt)
        }
        .confirmationDialog("Delete this debt?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                modelContext.delete(debt)
                try? modelContext.save()
                NotificationScheduler.refreshAll(context: modelContext)
                SnapshotService.refresh(context: modelContext)
                dismiss()
            }
        }
    }

    private var progressValue: Double {
        guard debt.originalAmount > 0 else { return 0 }
        return min(1, NSDecimalNumber(decimal: debt.totalRepaid).doubleValue / NSDecimalNumber(decimal: debt.originalAmount).doubleValue)
    }
}

/// Adds a partial repayment against a debt.
struct RepaymentSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let debt: Debt

    @State private var amountText = ""
    @State private var date = Date.now
    @State private var note = ""

    private var amount: Decimal? { Decimal.fromUserInput(amountText) }

    private var isValid: Bool {
        guard let amount else { return false }
        return amount.isPositive && amount <= debt.remaining
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CurrencyField(titleKey: "Amount", text: $amountText)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Note (optional)", text: $note)
                } footer: {
                    HStack(spacing: 4) {
                        Text("Remaining after this payment:")
                        AmountText(amount: max(0, debt.remaining - (amount ?? 0)))
                    }
                }
                Section {
                    Button("Pay Remaining Balance") {
                        amountText = "\(debt.remaining)"
                    }
                }
            }
            .navigationTitle("Add Repayment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amount else { return }
                        debt.addRepayment(amount: amount, date: date, note: note)
                        try? modelContext.save()
                        Haptics.shared.moneyConfirmed()
                        NotificationScheduler.refreshAll(context: modelContext)
                        SnapshotService.refresh(context: modelContext)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
