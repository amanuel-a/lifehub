//
//  BillDetailView.swift
//  LifeHub
//

import SwiftUI
import SwiftData
import PhotosUI

/// One bill: next due date with mark-paid, and the payment history that
/// builds up month after month (the rent history from the requirements).
struct BillDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.currencyCode) private var currencyCode

    @Bindable var bill: RecurringBill
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    @State private var showingEdit = false
    @State private var showingPayment = false
    @State private var paymentInitialDate = Date.now
    @State private var viewingReceipt: ReceiptImage?

    private var totalPaid: Decimal {
        bill.payments.reduce(Decimal.zero) { $0 + $1.amount }
    }

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

            Section {
                Button {
                    paymentInitialDate = bill.nextDueDate() ?? .now
                    showingPayment = true
                } label: {
                    Label("Record a Payment", systemImage: "plus.circle.fill")
                }
                Button {
                    paymentInitialDate = .now
                    showingPayment = true
                } label: {
                    Label("Add a Past Payment", systemImage: "clock.arrow.circlepath")
                }
            } footer: {
                Text("Back-date old payments, attach a receipt screenshot, or log several \(bill.frequency.periodNoun) at once.")
            }

            Section {
                let payments = bill.sortedPayments
                if payments.isEmpty {
                    Text("Payments you record appear here, building a history.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(payments) { payment in
                        paymentRow(payment)
                    }
                    .onDelete { offsets in
                        deletePayments(payments, at: offsets)
                    }
                }
            } header: {
                HStack {
                    Text("Payment History")
                    Spacer()
                    if !bill.payments.isEmpty {
                        Text("Total \(MoneyFormat.string(totalPaid, code: currencyCode))")
                            .textCase(nil)
                    }
                }
            }
        }
        .navigationTitle(bill.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        paymentInitialDate = bill.nextDueDate() ?? .now
                        showingPayment = true
                    } label: {
                        Label("Record Payment", systemImage: "plus.circle")
                    }
                    Button {
                        showingEdit = true
                    } label: {
                        Label("Edit Bill", systemImage: "pencil")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            BillFormView(bill: bill)
        }
        .sheet(isPresented: $showingPayment) {
            BillPaymentFormView(bill: bill, initialDate: paymentInitialDate)
        }
        .sheet(item: $viewingReceipt) { receipt in
            ReceiptViewer(imageData: receipt.data)
        }
    }

    @ViewBuilder
    private func paymentRow(_ payment: Expense) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(payment.date, format: .dateTime.day().month().year())
                if !payment.note.isEmpty {
                    Text(payment.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if let data = payment.receiptImageData, let image = UIImage(data: data) {
                Button {
                    viewingReceipt = ReceiptImage(data: data)
                } label: {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 34, height: 34)
                        .clipShape(.rect(cornerRadius: 7))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(.separator, lineWidth: 0.5)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("View receipt"))
            }
            AmountText(amount: payment.amount)
                .font(.subheadline.weight(.medium))
        }
    }

    private func deletePayments(_ payments: [Expense], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(payments[index])
        }
        try? modelContext.save()
        Haptics.shared.tap()
        NotificationScheduler.refreshAll(context: modelContext)
        SnapshotService.refresh(context: modelContext)
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

/// Record a payment against a recurring bill (rent, internet, …). Supports
/// back-dating an old payment, attaching a receipt screenshot, and logging a
/// single lump payment that covers several periods at once (e.g. "paid 3
/// months of rent"). Each covered period becomes its own linked expense so the
/// paid-state and monthly totals stay accurate.
struct BillPaymentFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currencyCode) private var currencyCode

    let bill: RecurringBill
    /// Prefills the date (e.g. the next due date).
    var initialDate: Date = .now

    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    @State private var amountText = ""
    @State private var date = Date.now
    @State private var periodsCovered = 1
    @State private var note = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var receiptData: Data?
    @FocusState private var amountFocused: Bool

    private var perPeriodAmount: Decimal? { Decimal.fromUserInput(amountText) }

    private var totalAmount: Decimal {
        (perPeriodAmount ?? 0) * Decimal(periodsCovered)
    }

    private var singularPeriodNoun: String {
        switch bill.frequency {
        case .weekly: String(localized: "week")
        case .monthly: String(localized: "month")
        case .quarterly: String(localized: "quarter")
        case .yearly: String(localized: "year")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CurrencyField(titleKey: "0", text: $amountText, prominent: true)
                        .focused($amountFocused)
                        .listRowBackground(Color.clear)
                } footer: {
                    Text("Amount for one \(singularPeriodNoun).")
                }

                Section("When") {
                    DatePicker("Payment Date", selection: $date, displayedComponents: .date)
                }

                Section {
                    Stepper(value: $periodsCovered, in: 1...24) {
                        HStack {
                            Text("Periods Covered")
                            Spacer()
                            Text("\(periodsCovered)")
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                        }
                    }
                } header: {
                    Text("Covers")
                } footer: {
                    if periodsCovered > 1 {
                        Text("Logs \(periodsCovered) \(bill.frequency.periodNoun) starting \(date, format: .dateTime.month().year()) — total \(MoneyFormat.string(totalAmount, code: currencyCode)).")
                    } else {
                        Text("Set higher if this one payment covered several \(bill.frequency.periodNoun).")
                    }
                }

                Section("Details") {
                    TextField("Note (optional)", text: $note)
                }

                Section("Receipt") {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(
                            receiptData == nil ? "Add Receipt Screenshot" : "Change Receipt Screenshot",
                            systemImage: "camera.fill"
                        )
                    }
                    if let receiptData, let image = UIImage(data: receiptData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                            .clipShape(.rect(cornerRadius: 12))
                            .contextMenu {
                                Button(role: .destructive) {
                                    self.receiptData = nil
                                    photoItem = nil
                                } label: {
                                    Label("Remove Photo", systemImage: "trash")
                                }
                            }
                            .accessibilityLabel(Text("Receipt photo"))
                    }
                }
            }
            .navigationTitle("Record Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!(perPeriodAmount?.isPositive ?? false))
                }
            }
            .onAppear(perform: populate)
            .task(id: photoItem) {
                guard let photoItem else { return }
                receiptData = try? await photoItem.loadTransferable(type: Data.self)
            }
        }
    }

    private func populate() {
        amountText = "\(bill.amount)"
        date = initialDate
        amountFocused = true
    }

    private func save() {
        guard let perPeriodAmount else { return }
        let calendar = Calendar.current
        let category = bill.isRent
            ? categories.first { $0.name.caseInsensitiveCompare("Rent") == .orderedSame }
            : categories.first { $0.name.caseInsensitiveCompare("Utilities") == .orderedSame }

        var periodDate = date
        for _ in 0..<periodsCovered {
            let expense = bill.markPaid(on: periodDate, amount: perPeriodAmount, category: category)
            if !note.isEmpty { expense.note = note }
            expense.receiptImageData = receiptData
            modelContext.insert(expense)
            periodDate = calendar.date(byAdding: bill.frequency.dateComponents, to: periodDate) ?? periodDate
        }

        try? modelContext.save()
        Haptics.shared.moneyConfirmed()
        NotificationScheduler.refreshAll(context: modelContext)
        SnapshotService.refresh(context: modelContext)
        dismiss()
    }
}

/// Identifiable wrapper so a receipt image can drive a `.sheet(item:)`.
private struct ReceiptImage: Identifiable {
    let id = UUID()
    let data: Data
}

/// A full-screen, pinch-to-zoom viewer for a receipt screenshot.
private struct ReceiptViewer: View {
    @Environment(\.dismiss) private var dismiss
    let imageData: Data

    @State private var scale: CGFloat = 1

    var body: some View {
        NavigationStack {
            Group {
                if let image = UIImage(data: imageData) {
                    ScrollView([.horizontal, .vertical]) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .gesture(
                                MagnifyGesture()
                                    .onChanged { scale = max(1, $0.magnification) }
                                    .onEnded { _ in withAnimation { scale = 1 } }
                            )
                    }
                } else {
                    ContentUnavailableView("Can't Load Receipt", systemImage: "photo")
                }
            }
            .navigationTitle("Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
