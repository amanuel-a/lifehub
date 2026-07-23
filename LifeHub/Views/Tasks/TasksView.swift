//
//  TasksView.swift
//  LifeHub
//

import SwiftUI
import SwiftData

/// To-dos grouped by project/area with priorities, due dates, recurrence,
/// and a done history.
struct TasksView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \TaskItem.createdAt, order: .reverse) private var allTasks: [TaskItem]
    @Query(sort: \TaskGroup.sortOrder) private var groups: [TaskGroup]

    @State private var showingForm = false
    @State private var editingTask: TaskItem?
    @State private var showingGroups = false
    @State private var filterGroup: TaskGroup?
    @State private var showDone = false

    private var openTasks: [TaskItem] {
        allTasks
            .filter { !$0.isCompleted }
            .filter { filterGroup == nil || $0.group?.uuid == filterGroup?.uuid }
            .sorted { lhs, rhs in
                let lDue = lhs.dueDate ?? .distantFuture
                let rDue = rhs.dueDate ?? .distantFuture
                if lDue != rDue { return lDue < rDue }
                return lhs.priority.sortRank < rhs.priority.sortRank
            }
    }

    private var overdue: [TaskItem] { openTasks.filter(\.isOverdue) }
    private var today: [TaskItem] {
        openTasks.filter { !$0.isOverdue && ($0.dueDate?.isToday ?? false) }
    }
    private var upcoming: [TaskItem] {
        openTasks.filter { !$0.isOverdue && !($0.dueDate?.isToday ?? false) && $0.dueDate != nil }
    }
    private var someday: [TaskItem] { openTasks.filter { $0.dueDate == nil } }

    private var doneTasks: [TaskItem] {
        allTasks
            .filter(\.isCompleted)
            .filter { filterGroup == nil || $0.group?.uuid == filterGroup?.uuid }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            List {
                if openTasks.isEmpty && doneTasks.isEmpty {
                    EmptyStateView(
                        titleKey: "No Tasks",
                        messageKey: "Add work and personal to-dos. Tasks with due dates appear on the calendar.",
                        symbolName: "checkmark.circle"
                    )
                    .listRowBackground(Color.clear)
                }

                taskSection("Overdue", tasks: overdue)
                taskSection("Today", tasks: today)
                taskSection("Upcoming", tasks: upcoming)
                taskSection("Someday", tasks: someday)

                if !doneTasks.isEmpty {
                    Section {
                        DisclosureGroup("Done (\(doneTasks.count))", isExpanded: $showDone) {
                            ForEach(doneTasks.prefix(30)) { task in
                                TaskRow(task: task) { toggle(task) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Filter", selection: $filterGroup) {
                            Text("All Groups").tag(nil as TaskGroup?)
                            ForEach(groups) { group in
                                Label(group.name, systemImage: group.symbolName)
                                    .tag(group as TaskGroup?)
                            }
                        }
                        Divider()
                        Button {
                            showingGroups = true
                        } label: {
                            Label("Edit Groups", systemImage: "folder.badge.gearshape")
                        }
                    } label: {
                        Label(
                            filterGroup?.name.isEmpty == false ? "\(filterGroup!.name)" : "All",
                            systemImage: "line.3.horizontal.decrease.circle"
                        )
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingForm = true
                    } label: {
                        Label("Add Task", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingForm) {
                TaskFormView(defaultGroup: filterGroup)
            }
            .sheet(item: $editingTask) { task in
                TaskFormView(task: task)
            }
            .sheet(isPresented: $showingGroups) {
                GroupsEditorView()
            }
        }
    }

    @ViewBuilder
    private func taskSection(_ title: LocalizedStringKey, tasks: [TaskItem]) -> some View {
        if !tasks.isEmpty {
            Section(title) {
                ForEach(tasks) { task in
                    TaskRow(task: task) { toggle(task) }
                        .contentShape(.rect)
                        .onTapGesture { editingTask = task }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                modelContext.delete(task)
                                persist()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    private func toggle(_ task: TaskItem) {
        if task.isCompleted {
            task.isCompleted = false
            task.completedAt = nil
            Haptics.shared.tap()
        } else {
            let fullyCompleted = task.complete()
            fullyCompleted ? Haptics.shared.success() : Haptics.shared.tap()
        }
        persist()
    }

    private func persist() {
        try? modelContext.save()
        NotificationScheduler.refreshAll(context: modelContext)
        SnapshotService.refresh(context: modelContext)
    }
}

/// One task row: completion circle, title, group/due metadata, priority tint.
struct TaskRow: View {
    let task: TaskItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? Color.green : task.priority.tint)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? Text("Mark as not done") : Text("Mark as done"))

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.isCompleted, color: .secondary)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                HStack(spacing: 6) {
                    if let group = task.group {
                        Label(group.name, systemImage: group.symbolName)
                            .font(.caption)
                            .foregroundStyle(Color(hex: group.colorHex))
                            .labelStyle(.titleAndIcon)
                    }
                    if task.repeatRule.repeats {
                        Image(systemName: "repeat")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(Text("Repeats"))
                    }
                    if let due = task.dueDate {
                        Text(task.hasDueTime ? due.formatted(date: .abbreviated, time: .shortened) : due.relativeDayDescription)
                            .font(.caption)
                            .foregroundStyle(task.isOverdue ? .red : .secondary)
                    }
                }
            }

            Spacer(minLength: 0)

            if task.priority == .high && !task.isCompleted {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                    .accessibilityLabel(Text("High priority"))
            }
        }
        .padding(.vertical, 2)
    }
}
