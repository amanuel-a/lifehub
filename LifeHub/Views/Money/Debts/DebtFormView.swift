//
//  DebtFormView.swift
//  LifeHub
//

import SwiftUI
import SwiftData

/// Add or edit a debt: person, direction, amount, date, optional due date, note.
struct DebtFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var debt: Debt?

    @State private var person = ""
    @State private var direction: DebtDirection = .iOwe
    @State private var amountText = ""
    @State private var date = Date.now
    @State private var hasDueDate = false
    @State private var dueDate = Date.now.addingTimeInterval(7 * 86_400)
    @State private var note = ""

    private var isEditing: Bool { debt != nil }
    private var amount: Decimal? { Decimal.fromUserInput(amountText) }

    private var canSave: Bool {
        !person.trimmingCharacters(in: .whitespaces).isEmpty && (amount?.isPositive ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Direction", selection: $direction) {
                        ForEach(DebtDirection.allCases) { direction in
                            Text(direction.titleKey).tag(direction)
                        }
                    }
                    .pickerStyle(.segmented)
                    TextField("Person", text: $person)
                        .textInputAutocapitalization(.words)
                    CurrencyField(titleKey: "Amount", text: $amountText)
                }

                Section("Dates") {
                    DatePicker("Borrowed on", selection: $date, displayedComponents: .date)
                    Toggle("Due date", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                    }
                }

                Section {
                    TextField("Note (optional)", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                } footer: {
                    if hasDueDate {
                        Text("You'll be reminded a few days before and on the due date.")
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Debt" : "New Debt")
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
        guard let debt else { return }
        person = debt.person
        direction = debt.direction
        amountText = "\(debt.originalAmount)"
        date = debt.date
        hasDueDate = debt.dueDate != nil
        dueDate = debt.dueDate ?? dueDate
        note = debt.note
    }

    private func save() {
        guard let amount else { return }
        let target = debt ?? {
            let new = Debt(person: person, direction: direction, amount: amount)
            modelContext.insert(new)
            return new
        }()

        target.person = person.trimmingCharacters(in: .whitespaces)
        target.direction = direction
        target.originalAmount = amount
        target.date = date
        target.dueDate = hasDueDate ? dueDate : nil
        target.note = note

        try? modelContext.save()
        Haptics.shared.success()
        NotificationScheduler.refreshAll(context: modelContext)
        SnapshotService.refresh(context: modelContext)
        dismiss()
    }
}
