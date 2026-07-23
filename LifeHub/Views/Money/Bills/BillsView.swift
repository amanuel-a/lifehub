//
//  BillsView.swift
//  LifeHub
//

import SwiftUI
import SwiftData

/// Rent and recurring bills: rent first, next due dates, paid state for the
/// current period, and swipe/menu actions to mark paid.
struct BillsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \RecurringBill.createdAt) private var bills: [RecurringBill]
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    @State private var showingForm = false
    @State private var editingBill: RecurringBill?

    private var rentBills: [RecurringBill] {
        bills.filter { $0.isRent && $0.isActive }
    }

    private var otherBills: [RecurringBill] {
        bills.filter { !$0.isRent && $0.isActive }
    }

    private var inactiveBills: [RecurringBill] {
        bills.filter { !$0.isActive }
    }

    var body: some View {
        List {
            if bills.isEmpty {
                EmptyStateView(
                    titleKey: "No Bills Yet",
                    messageKey: "Set up rent and other recurring bills once — LifeHub reminds you before each due date.",
                    symbolName: "house"
                )
                .listRowBackground(Color.clear)
            }

            if !rentBills.isEmpty {
                Section("Rent") {
                    ForEach(rentBills) { bill in
                        billRow(bill)
                    }
                }
            }

            if !otherBills.isEmpty {
                Section("Bills & Subscriptions") {
                    ForEach(otherBills) { bill in
                        billRow(bill)
                    }
                }
            }

            if !inactiveBills.isEmpty {
                Section("Paused") {
                    ForEach(inactiveBills) { bill in
                        billRow(bill)
                    }
                }
            }
        }
        .navigationTitle("Rent & Bills")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingForm = true
                } label: {
                    Label("Add Bill", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingForm) {
            BillFormView()
        }
        .sheet(item: $editingBill) { bill in
            BillFormView(bill: bill)
        }
    }

    private func billRow(_ bill: RecurringBill) -> some View {
        NavigationLink {
            BillDetailView(bill: bill)
        } label: {
            BillRow(bill: bill)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if nextDueIsUnpaid(bill) {
                Button {
                    markPaid(bill)
                } label: {
                    Label("Mark Paid", systemImage: "checkmark.circle.fill")
                }
                .tint(.green)
            }
        }
        .contextMenu {
            if nextDueIsUnpaid(bill) {
                Button {
                    markPaid(bill)
                } label: {
                    Label("Mark Paid", systemImage: "checkmark.circle.fill")
                }
            }
            Button {
                editingBill = bill
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                modelContext.delete(bill)
                try? modelContext.save()
                refresh()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func nextDueIsUnpaid(_ bill: RecurringBill) -> Bool {
        bill.isActive && bill.nextDueDate() != nil
    }

    private func markPaid(_ bill: RecurringBill) {
        let category = bill.isRent
            ? categories.first { $0.name.caseInsensitiveCompare("Rent") == .orderedSame }
            : categories.first { $0.name.caseInsensitiveCompare("Utilities") == .orderedSame }
        let expense = bill.markPaid(category: category)
        modelContext.insert(expense)
        try? modelContext.save()
        Haptics.shared.moneyConfirmed()
        refresh()
    }

    private func refresh() {
        NotificationScheduler.refreshAll(context: modelContext)
        SnapshotService.refresh(context: modelContext)
    }
}

/// One bill row: name/payee, next due countdown, amount.
struct BillRow: View {
    let bill: RecurringBill

    var body: some View {
        HStack(spacing: 12) {
            SymbolBadge(
                symbolName: bill.isRent ? "house.fill" : "doc.text.fill",
                color: bill.isRent ? .orange : .yellow
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(bill.name)
                    .font(.body.weight(.medium))
                if !bill.payee.isEmpty {
                    Text(bill.payee)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                AmountText(amount: bill.amount, compact: true)
                    .font(.subheadline.weight(.semibold))
                if let due = bill.nextDueDate() {
                    Text(due.relativeDayDescription)
                        .font(.caption)
                        .foregroundStyle(due.daysFromToday <= bill.remindBeforeDays ? .orange : .secondary)
                } else if !bill.isActive {
                    Text("Paused")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
