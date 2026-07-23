//
//  LoanDetailView.swift
//  LifeHub
//

import SwiftUI
import SwiftData

/// One loan: progress ring, next installment with record-payment, and the
/// installment history.
struct LoanDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currencyCode) private var currencyCode

    @Bindable var loan: Loan

    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 20) {
                    ProgressRing(progress: loan.progress, tint: .purple)
                        .frame(width: 84, height: 84)
                    VStack(alignment: .leading, spacing: 4) {
                        AmountText(amount: loan.remainingBalance)
                            .font(.title2.weight(.bold))
                        Text("remaining of \(MoneyFormat.string(loan.totalRepayable, code: currencyCode))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Text("Principal:")
                            AmountText(amount: loan.principal)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
                if !loan.note.isEmpty {
                    Text(loan.note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if !loan.isClosed {
                Section("Next Installment") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            AmountText(amount: loan.installmentAmount)
                                .font(.body.weight(.semibold))
                            Text("\(loan.nextDueDate, format: .dateTime.weekday(.wide).day().month()) · \(loan.nextDueDate.relativeDayDescription)")
                                .font(.subheadline)
                                .foregroundStyle(loan.nextDueDate.daysFromToday <= 3 ? .orange : .secondary)
                        }
                        Spacer()
                        Button {
                            recordInstallment()
                        } label: {
                            Label("Paid", systemImage: "checkmark.circle.fill")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                    Button {
                        LiveActivityManager.shared.startCountdown(
                            kind: .loan,
                            title: loan.lender,
                            amount: loan.installmentAmount,
                            currencyCode: currencyCode,
                            targetDate: loan.nextDueDate
                        )
                        Haptics.shared.tap()
                    } label: {
                        Label("Show Countdown on Lock Screen", systemImage: "clock.badge")
                    }
                }
            }

            Section("Payments") {
                let payments = loan.sortedPayments
                if payments.isEmpty {
                    Text("Recorded installments appear here.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(payments, id: \.uuid) { payment in
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
        .navigationTitle(loan.lender)
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
            LoanFormView(loan: loan)
        }
        .confirmationDialog("Delete this loan?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                modelContext.delete(loan)
                try? modelContext.save()
                NotificationScheduler.refreshAll(context: modelContext)
                SnapshotService.refresh(context: modelContext)
                dismiss()
            }
        }
    }

    private func recordInstallment() {
        loan.recordInstallment()
        try? modelContext.save()
        Haptics.shared.moneyConfirmed()
        LiveActivityManager.shared.completeCurrent()
        NotificationScheduler.refreshAll(context: modelContext)
        SnapshotService.refresh(context: modelContext)
    }
}

/// A simple determinate progress ring.
struct ProgressRing: View {
    let progress: Double
    var tint: Color = .accentColor
    var lineWidth: CGFloat = 10

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.5), value: progress)
            Text(progress, format: .percent.precision(.fractionLength(0)))
                .font(.headline.weight(.bold))
                .monospacedDigit()
        }
        .accessibilityElement()
        .accessibilityLabel(Text("\(Int(progress * 100)) percent repaid"))
    }
}
