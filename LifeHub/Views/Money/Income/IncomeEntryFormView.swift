//
//  IncomeEntryFormView.swift
//  LifeHub
//

import SwiftUI
import SwiftData

/// Manually log received income — a confirmed payday, a one-off payment,
/// or side-work cash.
struct IncomeEntryFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \IncomeSource.createdAt) private var sources: [IncomeSource]

    @State private var amountText = ""
    @State private var source: IncomeSource?
    @State private var date = Date.now
    @State private var note = ""

    private var amount: Decimal? { Decimal.fromUserInput(amountText) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CurrencyField(titleKey: "0", text: $amountText, prominent: true)
                        .listRowBackground(Color.clear)
                }

                Section {
                    Picker("Source", selection: $source) {
                        Text("No source").tag(nil as IncomeSource?)
                        ForEach(sources.filter(\.isActive)) { source in
                            Text(source.name).tag(source as IncomeSource?)
                        }
                    }
                    .onChange(of: source) { _, newValue in
                        if let newValue, amountText.isEmpty {
                            amountText = "\(newValue.amount)"
                        }
                    }
                    DatePicker("Received on", selection: $date, displayedComponents: .date)
                    TextField("Note (optional)", text: $note)
                }
            }
            .navigationTitle("Log Income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amount else { return }
                        let entry = IncomeEntry(amount: amount, dateReceived: date, note: note, source: source)
                        modelContext.insert(entry)
                        try? modelContext.save()
                        Haptics.shared.moneyConfirmed()
                        SnapshotService.refresh(context: modelContext)
                        dismiss()
                    }
                    .disabled(!(amount?.isPositive ?? false))
                }
            }
        }
    }
}
