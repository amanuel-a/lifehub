//
//  ModelContainerFactory.swift
//  LifeHub
//

import Foundation
import SwiftData

/// Builds the app's single `ModelContainer`, stored in the shared app-group
/// container so the database survives reinstall patterns consistently and
/// lives alongside widget snapshot data.
enum ModelContainerFactory {
    static let schema = Schema([
        IncomeSource.self,
        SalaryChange.self,
        IncomeEntry.self,
        ExpenseCategory.self,
        Expense.self,
        RecurringBill.self,
        Debt.self,
        DebtPayment.self,
        Loan.self,
        LoanPayment.self,
        CalendarEvent.self,
        TaskItem.self,
        TaskGroup.self,
        Note.self,
        Project.self,
        AppSettings.self
    ])

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            configuration = ModelConfiguration(schema: schema, groupContainer: .identifier(AppGroup.identifier))
        }
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // A corrupt store should not brick a personal, offline-first app.
            // Fall back to a local store rather than crashing.
            do {
                let fallback = ModelConfiguration(schema: schema)
                return try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                fatalError("Unable to create ModelContainer: \(error)")
            }
        }
    }

    /// An in-memory container seeded with defaults, for previews.
    @MainActor
    static func preview() -> ModelContainer {
        let container = makeContainer(inMemory: true)
        let context = container.mainContext
        for category in ExpenseCategory.defaultCategories() {
            context.insert(category)
        }
        for group in TaskGroup.defaultGroups() {
            context.insert(group)
        }
        context.insert(AppSettings())
        return container
    }
}
