//
//  TaskItem.swift
//  LifeHub
//

import Foundation
import SwiftData

/// A to-do item, optionally grouped by project/area, with priority,
/// due date, and recurrence.
@Model
final class TaskItem {
    @Attribute(.unique) var uuid: UUID
    var title: String
    var details: String
    var dueDate: Date?
    /// Whether `dueDate` includes a meaningful time of day.
    var hasDueTime: Bool
    var priorityRaw: String
    var repeatRule: RepeatRule
    var isCompleted: Bool
    var completedAt: Date?
    var group: TaskGroup?
    var createdAt: Date
    var sortOrder: Int

    init(
        title: String,
        details: String = "",
        dueDate: Date? = nil,
        hasDueTime: Bool = false,
        priority: TaskPriority = .normal,
        repeatRule: RepeatRule = .never,
        group: TaskGroup? = nil
    ) {
        self.uuid = UUID()
        self.title = title
        self.details = details
        self.dueDate = dueDate
        self.hasDueTime = hasDueTime
        self.priorityRaw = priority.rawValue
        self.repeatRule = repeatRule
        self.isCompleted = false
        self.completedAt = nil
        self.group = group
        self.createdAt = .now
        self.sortOrder = 0
    }

    var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRaw) ?? .normal }
        set { priorityRaw = newValue.rawValue }
    }

    var isOverdue: Bool {
        guard let dueDate, !isCompleted else { return false }
        if hasDueTime { return dueDate < .now }
        return Calendar.current.startOfDay(for: dueDate) < Calendar.current.startOfDay(for: .now)
    }

    /// Completes the task. A recurring task rolls its due date forward and
    /// stays open; a one-off task moves to the done history.
    /// Returns true when the task actually completed (vs. recurred).
    @discardableResult
    func complete(calendar: Calendar = .current) -> Bool {
        if repeatRule.repeats, let due = dueDate,
           let next = repeatRule.nextOccurrence(after: max(due, .now), anchoredTo: due, calendar: calendar) {
            dueDate = next
            return false
        }
        isCompleted = true
        completedAt = .now
        return true
    }
}

/// A project or area grouping tasks (e.g. "Work", "Home", "Personal").
@Model
final class TaskGroup {
    @Attribute(.unique) var uuid: UUID
    var name: String
    var symbolName: String
    var colorHex: String
    var sortOrder: Int

    @Relationship(deleteRule: .nullify, inverse: \TaskItem.group)
    var tasks: [TaskItem] = []

    init(name: String, symbolName: String = "folder.fill", colorHex: String = "#3B82F6", sortOrder: Int = 0) {
        self.uuid = UUID()
        self.name = name
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.sortOrder = sortOrder
    }

    var openTaskCount: Int {
        tasks.filter { !$0.isCompleted }.count
    }

    static func defaultGroups() -> [TaskGroup] {
        [
            TaskGroup(name: String(localized: "Work"), symbolName: "briefcase.fill", colorHex: "#3B82F6", sortOrder: 0),
            TaskGroup(name: String(localized: "Home"), symbolName: "house.fill", colorHex: "#F97316", sortOrder: 1),
            TaskGroup(name: String(localized: "Personal"), symbolName: "person.fill", colorHex: "#22C55E", sortOrder: 2)
        ]
    }
}
