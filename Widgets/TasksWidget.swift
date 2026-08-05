//
//  TasksWidget.swift
//  LifeHubWidgets
//

import WidgetKit
import SwiftUI
import AppIntents

/// Marks a task complete straight from the Home Screen. It runs in the widget
/// process, so it records the completion into the shared app group and updates
/// the snapshot immediately; the app applies it to the database on next launch.
struct CompleteTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Complete Task"

    @Parameter(title: "Task ID")
    var taskID: String

    init() {}
    init(taskID: String) { self.taskID = taskID }

    func perform() async throws -> some IntentResult {
        let defaults = AppGroup.defaults

        // Queue the completion for the app to apply.
        var pending = defaults.stringArray(forKey: AppGroup.pendingCompletedTasksKey) ?? []
        if !pending.contains(taskID) { pending.append(taskID) }
        defaults.set(pending, forKey: AppGroup.pendingCompletedTasksKey)

        // Reflect it in the snapshot right away so the widget re-renders done.
        var snapshot = WidgetSnapshotStore.load()
        snapshot.openTasks.removeAll { $0.id == taskID }
        snapshot.openTaskCount = max(0, snapshot.openTaskCount - 1)
        WidgetSnapshotStore.save(snapshot)

        return .result()
    }
}

/// "Tasks" — your open to-dos with a tappable checkbox to complete each one.
struct TasksWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LifeHubTasks", provider: SnapshotProvider()) { entry in
            TasksWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Tasks")
        .description("Your open tasks — check them off right from the Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct TasksWidgetView: View {
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
            HStack {
                Label("Tasks", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.indigo)
                Spacer()
                if entry.snapshot.openTaskCount > 0 {
                    Text("\(entry.snapshot.openTaskCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }

            if entry.snapshot.openTasks.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text("All done 🎉")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(entry.snapshot.openTasks.prefix(limit)) { task in
                    HStack(spacing: 8) {
                        Button(intent: CompleteTaskIntent(taskID: task.id)) {
                            Image(systemName: "circle")
                                .font(.body)
                                .foregroundStyle(task.overdue ? .red : .indigo)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(task.title)
                                .font(.caption)
                                .lineLimit(1)
                            if let due = task.due {
                                Text(relativeDayText(for: due))
                                    .font(.caption2)
                                    .foregroundStyle(task.overdue ? .red : .secondary)
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
