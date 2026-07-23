//
//  LoanFormView.swift
//  LifeHub
//

import SwiftUI
import SwiftData

/// Add or edit a loan: lender, principal, total to repay, installment,
/// frequency, and next due date.
struct LoanFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var loan: Loan?

    @State private var lender = ""
    @State private var principalText = ""
    @State private var totalText = ""
    @State private var installmentText = ""
    @State private var frequency: LoanFrequency = .monthly
    @State private var nextDueDate = Date.now.addingTimeInterval(30 * 86_400)
    @State private var startDate = Date.now
    @State private var note = ""

    private var isEditing: Bool { loan != nil }
    private var principal: Decimal? { Decimal.fromUserInput(principalText) }
    private var total: Decimal? { Decimal.fromUserInput(totalText) }
    private var installment: Decimal? { Decimal.fromUserInput(installmentText) }

    private var canSave: Bool {
        !lender.trimmingCharacters(in: .whitespaces).isEmpty
            && (principal?.isPositive ?? false)
            && (total?.isPositive ?? false)
            && (installment?.isPositive ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Lender (e.g. bank name)", text: $lender)
                        .textInputAutocapitalization(.words)
                    DatePicker("Loan start", selection: $startDate, displayedComponents: .date)
                }

                Section("Amounts") {
                    CurrencyField(titleKey: "Principal borrowed", text: $principalText)
                    CurrencyField(titleKey: "Total to repay", text: $totalText)
                    CurrencyField(titleKey: "Installment amount", text: $installmentText)
                }

                Section("Schedule") {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(LoanFrequency.allCases) { frequency in
                            Text(frequency.titleKey).tag(frequency)
                        }
                    }
                    .pickerStyle(.segmented)
                    DatePicker("Next installment due", selection: $nextDueDate, displayedComponents: .date)
                }

                Section {
                    TextField("Note (optional)", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                } footer: {
                    Text("Each installment due date fires a reminder; the balance updates as you record payments.")
                }
            }
            .navigationTitle(isEditing ? "Edit Loan" : "New Loan")
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
        guard let loan else { return }
        lender = loan.lender
        principalText = "\(loan.principal)"
        totalText = "\(loan.totalRepayable)"
        installmentText = "\(loan.installmentAmount)"
        frequency = loan.frequency
        nextDueDate = loan.nextDueDate
        startDate = loan.startDate
        note = loan.note
    }

    private func save() {
        guard let principal, let total, let installment else { return }
        let target = loan ?? {
            let new = Loan(
                lender: lender,
                principal: principal,
                totalRepayable: total,
                installmentAmount: installment,
                frequency: frequency,
                nextDueDate: nextDueDate,
                startDate: startDate
            )
            modelContext.insert(new)
            return new
        }()

        target.lender = lender.trimmingCharacters(in: .whitespaces)
        target.principal = principal
        target.totalRepayable = total
        target.installmentAmount = installment
        target.frequency = frequency
        target.nextDueDate = nextDueDate
        target.startDate = startDate
        target.note = note

        try? modelContext.save()
        Haptics.shared.success()
        NotificationScheduler.refreshAll(context: modelContext)
        SnapshotService.refresh(context: modelContext)
        dismiss()
    }
}
