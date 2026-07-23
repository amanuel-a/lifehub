//
//  CountdownLiveActivity.swift
//  LifeHubWidgets
//
//  The money-countdown Live Activity: Lock Screen presentation plus
//  compact, minimal, and expanded Dynamic Island layouts.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct CountdownLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CountdownActivityAttributes.self) { context in
            // Lock Screen / banner
            LockScreenCountdownView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.6))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.attributes.title)
                            .font(.headline)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: context.attributes.kind.symbolName)
                            .foregroundStyle(tint(for: context.attributes.kind))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(MoneyFormat.compactString(context.attributes.amount, code: context.attributes.currencyCode))
                        .font(.headline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(tint(for: context.attributes.kind))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.isDone {
                        Label(doneText(for: context.attributes.kind), systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity)
                    } else {
                        HStack {
                            Text(countdownLabel(for: context.attributes.kind))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(context.state.targetDate, style: .relative)
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isDone ? "checkmark.circle.fill" : context.attributes.kind.symbolName)
                    .foregroundStyle(context.state.isDone ? .green : tint(for: context.attributes.kind))
            } compactTrailing: {
                if context.state.isDone {
                    Text("Done")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                } else {
                    Text(shortDays(to: context.state.targetDate))
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(tint(for: context.attributes.kind))
                }
            } minimal: {
                Image(systemName: context.state.isDone ? "checkmark.circle.fill" : context.attributes.kind.symbolName)
                    .foregroundStyle(context.state.isDone ? .green : tint(for: context.attributes.kind))
            }
        }
    }

    private func tint(for kind: CountdownActivityAttributes.Kind) -> Color {
        switch kind {
        case .payday: .green
        case .rent: .orange
        case .loan: .purple
        case .debt: .pink
        }
    }

    private func countdownLabel(for kind: CountdownActivityAttributes.Kind) -> LocalizedStringKey {
        switch kind {
        case .payday: "Payday in"
        case .rent: "Rent due in"
        case .loan: "Installment due in"
        case .debt: "Debt due in"
        }
    }

    private func doneText(for kind: CountdownActivityAttributes.Kind) -> LocalizedStringKey {
        switch kind {
        case .payday: "Money arrived!"
        case .rent: "Rent paid"
        case .loan: "Installment paid"
        case .debt: "Debt settled"
        }
    }

    private func shortDays(to date: Date) -> String {
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: .now),
            to: Calendar.current.startOfDay(for: date)
        ).day ?? 0
        return days <= 0 ? String(localized: "Now") : "\(days)d"
    }
}

/// The Lock Screen presentation of the countdown.
struct LockScreenCountdownView: View {
    let context: ActivityViewContext<CountdownActivityAttributes>

    private var tint: Color {
        switch context.attributes.kind {
        case .payday: .green
        case .rent: .orange
        case .loan: .purple
        case .debt: .pink
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: context.state.isDone ? "checkmark.circle.fill" : context.attributes.kind.symbolName)
                .font(.title2)
                .foregroundStyle(context.state.isDone ? .green : tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if context.state.isDone {
                    Text("Done ✓")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                } else {
                    Text(context.state.targetDate, style: .relative)
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            Spacer()

            Text(MoneyFormat.compactString(context.attributes.amount, code: context.attributes.currencyCode))
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .padding(16)
    }
}
