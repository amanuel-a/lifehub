//
//  LifeHubIntents.swift
//  LifeHub
//
//  App Intents: Siri / Shortcuts / Spotlight integration for the quick
//  actions that matter — log an expense, add a task or note, and ask
//  "when is my next payday?".
//

import AppIntents
import Foundation
import SwiftData

// MARK: - Add Expense

struct AddExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Log an Expense"
    static let description = IntentDescription("Adds an expense to LifeHub.")

    @Parameter(title: "Amount")
    var amount: Double

    @Parameter(title: "Category", optionsProvider: CategoryOptionsProvider())
    var categoryName: String?

    @Parameter(title: "Note")
    var note: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) for \(\.$categoryName)") {
            \.$note
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount > 0 else {
            throw $amount.needsValueError("How much was it?")
        }
        let context = AppContainer.shared.mainContext
        var category: ExpenseCategory?
        if let categoryName {
            let descriptor = FetchDescriptor<ExpenseCategory>()
            category = (try? context.fetch(descriptor))?.first {
                $0.name.caseInsensitiveCompare(categoryName) == .orderedSame
            }
        }
        let expense = Expense(
            amount: Decimal(amount),
            date: .now,
            note: note ?? "",
            category: category
        )
        context.insert(expense)
        try context.save()
        SnapshotService.refresh(context: context)

        let settings = AppSettings.fetchOrCreate(in: context)
        let formatted = MoneyFormat.string(Decimal(amount), code: settings.currencyCode)
        return .result(dialog: "Logged \(formatted)\(category.map { " for \($0.name)" } ?? "").")
    }

    private struct CategoryOptionsProvider: DynamicOptionsProvider {
        @MainActor
        func results() async throws -> [String] {
            let context = AppContainer.shared.mainContext
            let categories = (try? context.fetch(FetchDescriptor<ExpenseCategory>())) ?? []
            return categories.sorted { $0.sortOrder < $1.sortOrder }.map(\.name)
        }
    }
}

// MARK: - Add Task

struct AddTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Add a Task"
    static let description = IntentDescription("Adds a to-do to LifeHub.")

    @Parameter(title: "Title")
    var taskTitle: String

    @Parameter(title: "Due Today")
    var dueToday: Bool?

    static var parameterSummary: some ParameterSummary {
        Summary("Add task \(\.$taskTitle)") {
            \.$dueToday
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = AppContainer.shared.mainContext
        let task = TaskItem(
            title: taskTitle,
            dueDate: (dueToday ?? false) ? Calendar.current.startOfDay(for: .now) : nil
        )
        context.insert(task)
        try context.save()
        NotificationScheduler.refreshAll(context: context)
        SnapshotService.refresh(context: context)
        return .result(dialog: "Added “\(taskTitle)”.")
    }
}

// MARK: - Add Note

struct AddNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Add a Note"
    static let description = IntentDescription("Captures a quick note in LifeHub.")

    @Parameter(title: "Text")
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("Note \(\.$text)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = AppContainer.shared.mainContext
        let note = Note(title: String(text.prefix(40)), body: text)
        context.insert(note)
        try context.save()
        return .result(dialog: "Noted.")
    }
}

// MARK: - Next Payday

struct NextPaydayIntent: AppIntent {
    static let title: LocalizedStringResource = "Next Payday"
    static let description = IntentDescription("Tells you when your next payday is.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = AppContainer.shared.mainContext
        let sources = (try? context.fetch(FetchDescriptor<IncomeSource>())) ?? []
        let next = sources
            .filter(\.isActive)
            .compactMap { source -> (String, Decimal, Date)? in
                guard let date = source.nextPayday() else { return nil }
                return (source.name, source.amount, date)
            }
            .min { $0.2 < $1.2 }

        guard let next else {
            return .result(dialog: "No paydays are set up yet.")
        }
        let settings = AppSettings.fetchOrCreate(in: context)
        let amount = MoneyFormat.string(next.1, code: settings.currencyCode)
        let when = next.2.formatted(.dateTime.weekday(.wide).day().month())
        return .result(dialog: "\(next.0) pays \(amount) on \(when) — \(next.2.relativeDayDescription.lowercased()).")
    }
}

// MARK: - Open Quick Add

struct OpenQuickAddIntent: AppIntent {
    static let title: LocalizedStringResource = "Quick Add in LifeHub"
    static let description = IntentDescription("Opens LifeHub ready to add an expense.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.selectedTab = .dashboard
        AppRouter.shared.pendingQuickAdd = .expense
        return .result()
    }
}

// MARK: - Shortcuts provider

struct LifeHubShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Log an expense in \(.applicationName)",
                "Add an expense to \(.applicationName)"
            ],
            shortTitle: "Log Expense",
            systemImageName: "cart.fill.badge.plus"
        )
        AppShortcut(
            intent: NextPaydayIntent(),
            phrases: [
                "When is my next payday in \(.applicationName)",
                "Ask \(.applicationName) about my payday"
            ],
            shortTitle: "Next Payday",
            systemImageName: "banknote.fill"
        )
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "Add a task in \(.applicationName)"
            ],
            shortTitle: "Add Task",
            systemImageName: "checkmark.circle.fill"
        )
        AppShortcut(
            intent: AddNoteIntent(),
            phrases: [
                "Take a note in \(.applicationName)"
            ],
            shortTitle: "Add Note",
            systemImageName: "note.text.badge.plus"
        )
    }
}
