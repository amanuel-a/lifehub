//
//  NotesWidget.swift
//  LifeHubWidgets
//

import WidgetKit
import SwiftUI

/// "Notes" — your pinned and most recent notes at a glance.
struct NotesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LifeHubNotes", provider: SnapshotProvider()) { entry in
            NotesWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Notes")
        .description("Your pinned and most recent notes.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct NotesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var limit: Int {
        switch family {
        case .systemSmall: return 3
        case .systemMedium: return 4
        default: return 7
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notes", systemImage: "note.text")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.yellow)

            if entry.snapshot.recentNotes.isEmpty {
                Spacer()
                Text("No notes yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(entry.snapshot.recentNotes.prefix(limit)) { note in
                    HStack(spacing: 6) {
                        Image(systemName: note.pinned ? "pin.fill" : "note.text")
                            .font(.caption2)
                            .foregroundStyle(note.pinned ? .orange : .secondary)
                            .frame(width: 14)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(note.title)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                            if family != .systemSmall, !note.snippet.isEmpty {
                                Text(note.snippet)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

/// "Projects" — progress across the ventures you're building.
struct ProjectsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LifeHubProjects", provider: SnapshotProvider()) { entry in
            ProjectsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Projects")
        .description("Progress across your projects.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct ProjectsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var limit: Int { family == .systemSmall ? 2 : (family == .systemMedium ? 3 : 6) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Projects", systemImage: "square.stack.3d.up.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                Spacer()
                if entry.snapshot.activeProjectCount > 0 {
                    Text("\(entry.snapshot.activeProjectCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }

            if entry.snapshot.projects.isEmpty {
                Spacer()
                Text("No projects yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(entry.snapshot.projects.prefix(limit)) { project in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(project.name)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(project.status)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(value: project.progress)
                            .tint(.blue)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}
