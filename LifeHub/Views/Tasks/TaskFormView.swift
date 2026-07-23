//
//  TaskFormView.swift
//  LifeHub
//

import SwiftUI
import SwiftData

/// Create or edit a task: title, group, due date/time, priority,
/// recurrence, notes.
struct TaskFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var task: TaskItem?
    var defaultGroup: TaskGroup?

    @Query(sort: \TaskGroup.sortOrder) private var groups: [TaskGroup]

    @State private var title = ""
    @State private var details = ""
    @State private var group: TaskGroup?
    @State private var hasDue = false
    @State private var dueDate = Date.now
    @State private var hasDueTime = false
    @State private var priority: TaskPriority = .normal
    @State private var repeatRule = RepeatRule.never

    private var isEditing: Bool { task != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What needs doing?", text: $title)
                    Picker("Group", selection: $group) {
                        Text("None").tag(nil as TaskGroup?)
                        ForEach(groups) { group in
                            Label(group.name, systemImage: group.symbolName)
                                .tag(group as TaskGroup?)
                        }
                    }
                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases) { priority in
                            Text(priority.titleKey).tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle("Due date", isOn: $hasDue.animation())
                    if hasDue {
                        DatePicker("Date", selection: $dueDate, displayedComponents: .date)
                        Toggle("At a specific time", isOn: $hasDueTime.animation())
                        if hasDueTime {
                            DatePicker("Time", selection: $dueDate, displayedComponents: .hourAndMinute)
                        }
                        RepeatRulePicker(rule: $repeatRule)
                    }
                } header: {
                    Text("Due")
                } footer: {
                    if hasDue {
                        Text("Tasks with due dates appear on the calendar and fire reminders.")
                    }
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $details, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(isEditing ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: populate)
        }
    }

    private func populate() {
        if let task {
            title = task.title
            details = task.details
            group = task.group
            hasDue = task.dueDate != nil
            dueDate = task.dueDate ?? .now
            hasDueTime = task.hasDueTime
            priority = task.priority
            repeatRule = task.repeatRule
        } else {
            group = defaultGroup
        }
    }

    private func save() {
        let target = task ?? {
            let new = TaskItem(title: title)
            modelContext.insert(new)
            return new
        }()

        target.title = title.trimmingCharacters(in: .whitespaces)
        target.details = details
        target.group = group
        target.dueDate = hasDue ? dueDate : nil
        target.hasDueTime = hasDue && hasDueTime
        target.priority = priority
        target.repeatRule = hasDue ? repeatRule : .never

        try? modelContext.save()
        Haptics.shared.success()
        NotificationScheduler.refreshAll(context: modelContext)
        SnapshotService.refresh(context: modelContext)
        dismiss()
    }
}

/// Manage task groups: add, rename, recolor, delete.
struct GroupsEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \TaskGroup.sortOrder) private var groups: [TaskGroup]

    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Groups") {
                    ForEach(groups) { group in
                        HStack {
                            SymbolBadge(symbolName: group.symbolName, color: Color(hex: group.colorHex))
                            Text(group.name)
                            Spacer()
                            Text("\(group.openTaskCount)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .onDelete { offsets in
                        for offset in offsets {
                            modelContext.delete(groups[offset])
                        }
                        try? modelContext.save()
                    }
                }

                Section("Add Group") {
                    HStack {
                        TextField("Name", text: $newName)
                        Button {
                            addGroup()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityLabel(Text("Add group"))
                    }
                }
            }
            .navigationTitle("Task Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func addGroup() {
        let colors = PaletteColors.hexes
        let group = TaskGroup(
            name: newName.trimmingCharacters(in: .whitespaces),
            symbolName: "folder.fill",
            colorHex: colors[groups.count % colors.count],
            sortOrder: (groups.map(\.sortOrder).max() ?? 0) + 1
        )
        modelContext.insert(group)
        try? modelContext.save()
        newName = ""
        Haptics.shared.tap()
    }
}
