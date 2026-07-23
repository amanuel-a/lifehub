//
//  IncomeSourceDetailView.swift
//  LifeHub
//

import SwiftUI
import SwiftData
import Charts

/// One income source: tenure, next payday with confirm-receipt, salary
/// growth over time (chart + history), and received payments.
struct IncomeSourceDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currencyCode) private var currencyCode

    @Bindable var source: IncomeSource

    @State private var showingEdit = false
    @State private var showingSalaryChange = false
    @State private var showingEndJobConfirm = false
    @State private var showingDeleteConfirm = false

    var body: some View {
        List {
            headerSection
            if source.isActive { nextPaydaySection }
            salaryHistorySection
            receivedSection
        }
        .navigationTitle(source.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingEdit = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button {
                        showingSalaryChange = true
                    } label: {
                        Label("Record Salary Change", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    if source.isActive {
                        Button {
                            showingEndJobConfirm = true
                        } label: {
                            Label("Mark as Ended", systemImage: "flag.checkered")
                        }
                    }
                    Divider()
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
            IncomeSourceFormView(source: source)
        }
        .sheet(isPresented: $showingSalaryChange) {
            SalaryChangeSheet(source: source)
        }
        .confirmationDialog("Mark this job as ended?", isPresented: $showingEndJobConfirm, titleVisibility: .visible) {
            Button("Mark as Ended") {
                source.endDate = .now
                saveAndRefresh()
            }
        } message: {
            Text("It moves to Past Jobs and stops firing payday reminders. Its history is kept.")
        }
        .confirmationDialog("Delete this income source?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                modelContext.delete(source)
                saveAndRefresh()
                dismiss()
            }
        } message: {
            Text("Its salary history and received payments are deleted too.")
        }
    }

    // MARK: Sections

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    SymbolBadge(symbolName: source.type.symbolName, color: source.isActive ? .green : .gray, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        AmountText(amount: source.amount)
                            .font(.title2.weight(.bold))
                        HStack(spacing: 4) {
                            Text(source.type.titleKey)
                            Text("·")
                            Text(source.frequency.titleKey)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                if let tenure = source.tenureDescription {
                    Label {
                        source.isActive
                            ? Text("\(tenure) at \(source.name)")
                            : Text("Worked \(tenure)")
                    } icon: {
                        Image(systemName: "clock.badge.checkmark")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                }
                if !source.note.isEmpty {
                    Text(source.note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var nextPaydaySection: some View {
        Section("Next Payday") {
            if let next = source.nextPayday() {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(next, format: .dateTime.weekday(.wide).day().month())
                            .font(.body.weight(.medium))
                        Text(next.relativeDayDescription)
                            .font(.subheadline)
                            .foregroundStyle(next.isToday ? .green : .secondary)
                    }
                    Spacer()
                    Button {
                        confirmReceived(on: next.isToday ? next : .now)
                    } label: {
                        Label("Money Arrived", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                Button {
                    LiveActivityManager.shared.startCountdown(
                        kind: .payday,
                        title: source.name,
                        amount: source.amount,
                        currencyCode: currencyCode,
                        targetDate: next
                    )
                    Haptics.shared.tap()
                } label: {
                    Label("Show Countdown on Lock Screen", systemImage: "clock.badge")
                }
            } else {
                Text("Set a pay schedule to see the next payday.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var salaryHistorySection: some View {
        Section("Salary History") {
            let history = source.sortedSalaryChanges
            if history.count > 1 {
                Chart(history, id: \.uuid) { change in
                    LineMark(
                        x: .value("Date", change.effectiveDate),
                        y: .value("Salary", NSDecimalNumber(decimal: change.amount).doubleValue)
                    )
                    .interpolationMethod(.stepEnd)
                    .foregroundStyle(Color.accentColor)
                    PointMark(
                        x: .value("Date", change.effectiveDate),
                        y: .value("Salary", NSDecimalNumber(decimal: change.amount).doubleValue)
                    )
                    .foregroundStyle(Color.accentColor)
                }
                .frame(height: 140)
                .padding(.vertical, 4)
                .accessibilityLabel(Text("Salary growth chart"))
            }
            if history.isEmpty {
                Text("No salary changes recorded yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(history.reversed(), id: \.uuid) { change in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            AmountText(amount: change.amount)
                                .font(.body.weight(.medium))
                            if !change.note.isEmpty {
                                Text(change.note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(change.effectiveDate, format: .dateTime.day().month().year())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var receivedSection: some View {
        Section("Received") {
            let entries = source.entries.sorted { $0.dateReceived > $1.dateReceived }
            if entries.isEmpty {
                Text("Confirmed paydays appear here as income records.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entries.prefix(12), id: \.uuid) { entry in
                    HStack {
                        Label {
                            Text(entry.dateReceived, format: .dateTime.day().month().year())
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        Spacer()
                        AmountText(amount: entry.amount)
                            .font(.subheadline.weight(.medium))
                    }
                }
            }
        }
    }

    // MARK: Actions

    private func confirmReceived(on date: Date) {
        let entry = IncomeEntry(amount: source.amount, dateReceived: date, source: source)
        modelContext.insert(entry)
        Haptics.shared.moneyConfirmed()
        LiveActivityManager.shared.completeCurrent()
        saveAndRefresh()
    }

    private func saveAndRefresh() {
        try? modelContext.save()
        NotificationScheduler.refreshAll(context: modelContext)
        SnapshotService.refresh(context: modelContext)
    }
}

/// Records a salary change with an effective date.
struct SalaryChangeSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let source: IncomeSource

    @State private var amountText = ""
    @State private var effectiveDate = Date.now
    @State private var note = ""

    private var amount: Decimal? { Decimal.fromUserInput(amountText) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CurrencyField(titleKey: "New salary", text: $amountText)
                    DatePicker("Effective from", selection: $effectiveDate, displayedComponents: .date)
                    TextField("Note (e.g. promotion)", text: $note)
                } footer: {
                    Text("LifeHub keeps every change so you can see how your salary grew at \(source.name).")
                }
            }
            .navigationTitle("Salary Change")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amount else { return }
                        source.recordSalaryChange(amount: amount, effectiveDate: effectiveDate, note: note)
                        try? modelContext.save()
                        Haptics.shared.success()
                        NotificationScheduler.refreshAll(context: modelContext)
                        SnapshotService.refresh(context: modelContext)
                        dismiss()
                    }
                    .disabled(!(amount?.isPositive ?? false))
                }
            }
        }
        .presentationDetents([.medium])
    }
}
