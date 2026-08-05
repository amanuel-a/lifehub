//
//  IncomeSourceFormView.swift
//  LifeHub
//

import SwiftUI
import SwiftData

/// Add or edit an income source: name, type, amount, pay schedule
/// ("every Friday", "the 28th of each month"), and job start date.
struct IncomeSourceFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var source: IncomeSource?

    @Environment(\.currencyCode) private var appCurrency

    @State private var name = ""
    @State private var type: IncomeType = .salary
    @State private var amountText = ""
    /// Either "USD" or "ETB" — toggled by tapping the code next to the amount.
    @State private var currency = "ETB"
    @State private var frequency: PayFrequency = .monthly

    private func supported(_ code: String) -> String {
        (code == "USD" || code == "ETB") ? code : "ETB"
    }
    @State private var paydayWeekday = 6 // Friday
    @State private var paydayDayOfMonth = 28
    @State private var biweeklyAnchor = Date.now
    @State private var hasStartDate = true
    @State private var startDate = Date.now
    @State private var note = ""

    private var isEditing: Bool { source != nil }

    private var amount: Decimal? { Decimal.fromUserInput(amountText) }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (amount?.isPositive ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Company or client name", text: $name)
                        .textInputAutocapitalization(.words)
                    Picker("Type", selection: $type) {
                        ForEach(IncomeType.allCases) { type in
                            Label {
                                Text(type.titleKey)
                            } icon: {
                                Image(systemName: type.symbolName)
                            }
                            .tag(type)
                        }
                    }
                }

                Section {
                    CurrencyField(titleKey: "Amount", text: $amountText, toggleableCurrency: $currency)
                    Picker("Frequency", selection: $frequency) {
                        ForEach(PayFrequency.allCases) { frequency in
                            Text(frequency.titleKey).tag(frequency)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch frequency {
                    case .weekly:
                        WeekdayPicker(titleKey: "Payday", selection: $paydayWeekday)
                    case .biweekly:
                        WeekdayPicker(titleKey: "Payday", selection: $paydayWeekday)
                        DatePicker("A recent payday", selection: $biweeklyAnchor, displayedComponents: .date)
                    case .monthly:
                        Picker("Day of month", selection: $paydayDayOfMonth) {
                            ForEach(1...31, id: \.self) { day in
                                Text("\(day)").tag(day)
                            }
                        }
                    }
                } header: {
                    Text("Pay")
                } footer: {
                    if frequency == .biweekly {
                        Text("Pick any payday you remember — LifeHub counts every 14 days from it.")
                    } else if frequency == .monthly {
                        Text("Short months are handled automatically (the 31st becomes the last day).")
                    }
                }

                Section("Job") {
                    Toggle("Track start date & tenure", isOn: $hasStartDate.animation())
                    if hasStartDate {
                        DatePicker("Started on", selection: $startDate, displayedComponents: .date)
                    }
                }

                Section("Note") {
                    TextField("Optional note", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                }
            }
            .navigationTitle(isEditing ? "Edit Income" : "New Income")
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
        guard let source else {
            currency = supported(appCurrency)
            return
        }
        name = source.name
        type = source.type
        amountText = "\(source.amount)"
        currency = supported(source.currencyCode ?? appCurrency)
        frequency = source.frequency
        paydayWeekday = source.paydayWeekday ?? 6
        paydayDayOfMonth = source.paydayDayOfMonth ?? 28
        biweeklyAnchor = source.biweeklyAnchor ?? .now
        hasStartDate = source.startDate != nil
        startDate = source.startDate ?? .now
        note = source.note
    }

    private func save() {
        guard let amount else { return }
        let target: IncomeSource
        if let source {
            target = source
            if source.amount != amount {
                // Editing the amount records a salary change effective today.
                source.recordSalaryChange(amount: amount, effectiveDate: .now)
            }
        } else {
            target = IncomeSource(name: name, type: type, amount: amount)
            modelContext.insert(target)
            // Seed the salary history with the initial amount.
            target.recordSalaryChange(amount: amount, effectiveDate: hasStartDate ? startDate : .now)
        }

        target.name = name.trimmingCharacters(in: .whitespaces)
        target.type = type
        target.amount = amount
        target.currencyCode = currency
        target.frequency = frequency
        target.paydayWeekday = frequency == .monthly ? nil : paydayWeekday
        target.paydayDayOfMonth = frequency == .monthly ? paydayDayOfMonth : nil
        target.biweeklyAnchor = frequency == .biweekly ? biweeklyAnchor : nil
        target.startDate = hasStartDate ? startDate : nil
        target.note = note

        try? modelContext.save()
        Haptics.shared.success()
        NotificationScheduler.refreshAll(context: modelContext)
        SnapshotService.refresh(context: modelContext)
        dismiss()
    }
}

/// Shared weekday picker using localized weekday names.
struct WeekdayPicker: View {
    let titleKey: LocalizedStringKey
    @Binding var selection: Int

    private var symbols: [String] {
        Calendar.current.standaloneWeekdaySymbols
    }

    var body: some View {
        Picker(titleKey, selection: $selection) {
            ForEach(1...7, id: \.self) { weekday in
                Text(symbols[weekday - 1]).tag(weekday)
            }
        }
    }
}
