//
//  PaydayWidget.swift
//  LifeHubWidgets
//

import WidgetKit
import SwiftUI

/// "Next Payday" — countdown to the closest payday, plus rent due.
/// Includes Lock Screen accessory families.
struct PaydayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LifeHubPayday", provider: SnapshotProvider()) { entry in
            PaydayWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next Payday")
        .description("Countdown to your next payday and rent day.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct PaydayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var code: String { entry.snapshot.currencyCode }

    var body: some View {
        switch family {
        case .accessoryInline:
            inline
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        default:
            small
        }
    }

    private var inline: some View {
        Group {
            if let payday = entry.snapshot.nextPayday {
                Text("💰 \(payday.sourceName): \(relativeDayText(for: payday.date))")
            } else {
                Text("No payday set")
            }
        }
    }

    private var circular: some View {
        VStack(spacing: 0) {
            Image(systemName: "banknote.fill")
                .font(.caption)
            if let payday = entry.snapshot.nextPayday {
                Text(daysLabel(for: payday.date))
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
            } else {
                Text(verbatim: "—")
            }
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let payday = entry.snapshot.nextPayday {
                Text(payday.sourceName)
                    .font(.headline)
                Text("Payday \(relativeDayText(for: payday.date).lowercased())")
                    .font(.caption)
                if let rent = entry.snapshot.nextRent {
                    Text("Rent \(relativeDayText(for: rent.date).lowercased())")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Set up income in LifeHub")
                    .font(.caption)
            }
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Payday", systemImage: "banknote.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)

            if let payday = entry.snapshot.nextPayday {
                Text(relativeDayText(for: payday.date))
                    .font(.title2.weight(.bold))
                    .minimumScaleFactor(0.7)
                Text(payday.sourceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(MoneyFormat.compactString(payday.amount, code: code))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.green)
            } else {
                Text("No income sources yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if let rent = entry.snapshot.nextRent {
                HStack(spacing: 4) {
                    Image(systemName: "house.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text("Rent \(relativeDayText(for: rent.date).lowercased())")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func daysLabel(for date: Date) -> String {
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: .now),
            to: Calendar.current.startOfDay(for: date)
        ).day ?? 0
        return days == 0 ? String(localized: "Now") : "\(days)d"
    }
}
