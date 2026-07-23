//
//  BillFormView.swift
//  LifeHub
//

import SwiftUI
import SwiftData

/// Add or edit a recurring bill. Rent gets landlord + a default 3-day
/// early reminder; everything else defaults to 1 day before.
struct BillFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var bill: RecurringBill?

    @State private var name = ""
    @State private var isRent = false
    @State private var amountText = ""
    @State private var frequency: BillFrequency = .monthly
    @State private var dueDay = 1
    @State private var dueMonth = 1
    @State private var dueWeekday = 2
    @State private var payee = ""
    @State private var remindBeforeDays = 1
    @State private var isActive = true
    @State private var note = ""

    private var isEditing: Bool { bill != nil }
    private var amount: Decimal? { Decimal.fromUserInput(amountText) }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (amount?.isPositive ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $isRent.animation()) {
                        Label("This is my rent", systemImage: "house.fill")
                    }
                    .onChange(of: isRent) { _, nowRent in
                        if !isEditing {
                            remindBeforeDays = nowRent ? 3 : 1
                            if nowRent, name.isEmpty { name = String(localized: "Rent") }
                        }
                    }
                    TextField(isRent ? "Name (e.g. Rent)" : "Name (e.g. Internet)", text: $name)
                    TextField(isRent ? "Landlord name" : "Payee (optional)", text: $payee)
                }

                Section("Amount & Schedule") {
                    CurrencyField(titleKey: "Amount", text: $amountText)
                    Picker("Repeats", selection: $frequency) {
                        ForEach(BillFrequency.allCases) { frequency in
                            Text(frequency.titleKey).tag(frequency)
                        }
                    }
                    switch frequency {
                    case .weekly:
                        WeekdayPicker(titleKey: "Due on", selection: $dueWeekday)
                    case .monthly, .quarterly:
                        Picker("Due day", selection: $dueDay) {
                            ForEach(1...31, id: \.self) { day in
                                Text("\(day)").tag(day)
                            }
                        }
                        if frequency == .quarterly {
                            Picker("Starting month", selection: $dueMonth) {
                                ForEach(1...12, id: \.self) { month in
                                    Text(Calendar.current.standaloneMonthSymbols[month - 1]).tag(month)
                                }
                            }
                        }
                    case .yearly:
                        Picker("Due month", selection: $dueMonth) {
                            ForEach(1...12, id: \.self) { month in
                                Text(Calendar.current.standaloneMonthSymbols[month - 1]).tag(month)
                            }
                        }
                        Picker("Due day", selection: $dueDay) {
                            ForEach(1...31, id: \.self) { day in
                                Text("\(day)").tag(day)
                            }
                        }
                    }
                }

                Section("Reminder") {
                    Stepper(value: $remindBeforeDays, in: 0...14) {
                        if remindBeforeDays == 0 {
                            Text("Only on the due day")
                        } else {
                            Text("\(remindBeforeDays) days before + on the day")
                        }
                    }
                }

                Section {
                    if isEditing {
                        Toggle("Active", isOn: $isActive)
                    }
                    TextField("Note (optional)", text: $note)
                }
            }
            .navigationTitle(isEditing ? "Edit Bill" : (isRent ? "New Rent" : "New Bill"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: populate)
        }
    }

    private func populate() {
        guard let bill else { return }
        name = bill.name
        isRent = bill.isRent
        amountText = "\(bill.amount)"
        frequency = bill.frequency
        dueDay = bill.dueDay
        dueMonth = bill.dueMonth
        dueWeekday = bill.dueWeekday ?? 2
        payee = bill.payee
        remindBeforeDays = bill.remindBeforeDays
        isActive = bill.isActive
        note = bill.note
    }

    private func save() {
        guard let amount else { return }
        let target = bill ?? {
            let new = RecurringBill(name: name, amount: amount)
            modelContext.insert(new)
            return new
        }()

        target.name = name.trimmingCharacters(in: .whitespaces)
        target.isRent = isRent
        target.amount = amount
        target.frequency = frequency
        target.dueDay = dueDay
        target.dueMonth = dueMonth
        target.dueWeekday = frequency == .weekly ? dueWeekday : nil
        target.payee = payee
        target.remindBeforeDays = remindBeforeDays
        target.isActive = isActive
        target.note = note

        try? modelContext.save()
        Haptics.shared.success()
        NotificationScheduler.refreshAll(context: modelContext)
        SnapshotService.refresh(context: modelContext)
        dismiss()
    }
}
