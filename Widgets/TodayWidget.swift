//
//  TodayWidget.swift
//  LifeHubWidgets
//

import WidgetKit
import SwiftUI

/// "Today" — a glanceable list of what's due today: reminders, events,
/// tasks, and money items. Supports small, medium, and Lock Screen sizes.
struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LifeHubToday", provider: SnapshotProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today")
        .description("What's due today — events, tasks, bills, and paydays.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            accessory
        default:
            standard
        }
    }

    private var accessory: some View {
        VStack(alignment: .leading, spacing: 2) {
            if entry.snapshot.todayLines.isEmpty {
                Text("Nothing due today")
                    .font(.headline)
            } else {
                ForEach(entry.snapshot.todayLines.prefix(2).indices, id: \.self) { index in
                    let line = entry.snapshot.todayLines[index]
                    HStack(spacing: 4) {
                        Image(systemName: line.symbolName)
                            .font(.caption2)
                        Text(line.title)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private var standard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Today", systemImage: "sun.max.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                Spacer()
                if entry.snapshot.openTaskCount > 0 {
                    Text("\(entry.snapshot.openTaskCount) open")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if entry.snapshot.todayLines.isEmpty {
                Spacer()
                Text("Nothing due today 🎉")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                let limit = family == .systemSmall ? 3 : 5
                ForEach(entry.snapshot.todayLines.prefix(limit).indices, id: \.self) { index in
                    let line = entry.snapshot.todayLines[index]
                    HStack(spacing: 6) {
                        Image(systemName: line.symbolName)
                            .font(.caption)
                            .foregroundStyle(.tint)
                            .frame(width: 14)
                        Text(line.title)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if let time = line.time {
                            Text(time, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}
