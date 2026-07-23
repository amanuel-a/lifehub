//
//  BillDetailView.swift
//  LifeHub
//

import SwiftUI
import SwiftData

/// One bill: next due date with mark-paid, and the payment history that
/// builds up month after month (the rent history from the requirements).
struct BillDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.currencyCode) private var currencyCode

    @Bindable var bill: RecurringBill
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    @State private var showingEdit = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    SymbolBadge(
                        symbolName: bill.isRent ? "house.fill" : "doc.text.fill",
                        color: bill.isRent ? .orange : .yellow,
                        size: 44
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        AmountText(amount: bill.amount)
                            .font(.title2.weight(.bold))
                        HStack(spacing: 4) {
                            Text(bill.frequency.titleKey)
                            if !bill.payee.isEmpty {
                                Text("·")
                                Text(bill.payee)
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                if !bill.note.isEmpty {
                    Text(bill.note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if bill.isActive {
                Section("Next Due") {
                    if let due = bill.nextDueDate() {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(due, format: .dateTime.weekday(.wide).day().month())
                                    .font(.body.weight(.medium))
                                Text(due.relativeDayDescription)
                                    .font(.subheadline)
                                    .foregroundStyle(due.daysFromToday <= bill.remindBeforeDays ? .orange : .secondary)
                            }
                            Spacer()
                            Button {
                                markPaid()
                            } label: {
                                Label("Mark Paid", systemImage: "checkmark.circle.fill")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }
                        Label {
                            Text("Reminder \(bill.remindBeforeDays) days before + on the day")
                        } icon: {
                            Image(systemName: "bell.badge.fill")
                                .foregroundStyle(.orange)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                        if bill.isRent {
                            Button {
                                LiveActivityManager.shared.startCountdown(
                                    kind: .rent,
                                    title: bill.name,
                                    amount: bill.amount,
                                    currencyCode: currencyCode,
                                    targetDate: due
                                )
                                Haptics.shared.tap()
                            } label: {
                                Label("Show Countdown on Lock Screen", systemImage: "clock.badge")
                            }
                        }
                    }
                }
            }

            Section("Payment History") {
                let payments = bill.sortedPayments
                if payments.isEmpty {
                    Text("Payments you mark appear here, building a history.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(payments) { payment in
                        HStack {
                            Label {
                                Text(payment.date, format: .dateTime.day().month().year())
                            } icon: {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                            Spacer()
                            AmountText(amount: payment.amount)
                                .font(.subheadline.weight(.medium))
                        }
                    }
                }
            }
        }
        .navigationTitle(bill.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            BillFormView(bill: bill)
        }
    }

    private func markPaid() {
        let category = bill.isRent
            ? categories.first { $0.name.caseInsensitiveCompare("Rent") == .orderedSame }
            : categories.first { $0.name.caseInsensitiveCompare("Utilities") == .orderedSame }
        let expense = bill.markPaid(category: category)
        modelContext.insert(expense)
        try? modelContext.save()
        Haptics.shared.moneyConfirmed()
        LiveActivityManager.shared.completeCurrent()
        NotificationScheduler.refreshAll(context: modelContext)
        SnapshotService.refresh(context: modelContext)
    }
}
