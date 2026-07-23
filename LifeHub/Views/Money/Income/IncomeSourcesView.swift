//
//  IncomeSourcesView.swift
//  LifeHub
//

import SwiftUI
import SwiftData

/// All income sources — current ones with next-payday countdowns, and the
/// job history with past salaries.
struct IncomeSourcesView: View {
    @Query(sort: \IncomeSource.createdAt) private var sources: [IncomeSource]

    @State private var showingForm = false

    private var activeSources: [IncomeSource] {
        sources.filter(\.isActive)
    }

    private var pastSources: [IncomeSource] {
        sources.filter { !$0.isActive }
    }

    var body: some View {
        List {
            if sources.isEmpty {
                EmptyStateView(
                    titleKey: "No Income Yet",
                    messageKey: "Add your salary or side work to start tracking paydays and tenure.",
                    symbolName: "banknote"
                )
                .listRowBackground(Color.clear)
            }

            if !activeSources.isEmpty {
                Section("Current") {
                    ForEach(activeSources) { source in
                        NavigationLink {
                            IncomeSourceDetailView(source: source)
                        } label: {
                            IncomeSourceRow(source: source)
                        }
                    }
                }
            }

            if !pastSources.isEmpty {
                Section("Past Jobs") {
                    ForEach(pastSources) { source in
                        NavigationLink {
                            IncomeSourceDetailView(source: source)
                        } label: {
                            IncomeSourceRow(source: source)
                        }
                    }
                }
            }
        }
        .navigationTitle("Income & Salary")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingForm = true
                } label: {
                    Label("Add Income Source", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingForm) {
            IncomeSourceFormView()
        }
    }
}

/// One income source row: name, schedule, next payday countdown, amount.
struct IncomeSourceRow: View {
    let source: IncomeSource

    var body: some View {
        HStack(spacing: 12) {
            SymbolBadge(symbolName: source.type.symbolName, color: source.isActive ? .green : .gray)

            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                    .font(.body.weight(.medium))
                HStack(spacing: 4) {
                    Text(source.frequency.titleKey)
                    if let tenure = source.tenureDescription {
                        Text("·")
                        Text(tenure)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                AmountText(amount: source.amount, compact: true)
                    .font(.subheadline.weight(.semibold))
                if let next = source.nextPayday() {
                    Text(next.relativeDayDescription)
                        .font(.caption)
                        .foregroundStyle(next.isToday ? .green : .secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
