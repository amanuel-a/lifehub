//
//  BackupService.swift
//  LifeHub
//
//  One-tap export of everything to a single JSON file, and restore from it.
//  DTOs are versioned and decoupled from the SwiftData models so old backups
//  keep restoring as the schema evolves.
//

import Foundation
import SwiftData

// MARK: - Backup document

struct LifeHubBackup: Codable {
    var version: Int = 1
    var exportedAt: Date = .now

    var settings: SettingsDTO?
    var categories: [CategoryDTO] = []
    var incomeSources: [IncomeSourceDTO] = []
    var expenses: [ExpenseDTO] = []
    var bills: [BillDTO] = []
    var debts: [DebtDTO] = []
    var loans: [LoanDTO] = []
    var events: [EventDTO] = []
    var taskGroups: [TaskGroupDTO] = []
    var tasks: [TaskDTO] = []
    var notes: [NoteDTO] = []

    // MARK: DTOs

    struct SettingsDTO: Codable {
        var currencyCode: String
        var rentRemindBeforeDays: Int
        var billRemindBeforeDays: Int
        var debtRemindBeforeDays: Int
        var loanRemindBeforeDays: Int
        var eventReminderMinutes: Int
        var reminderHour: Int
        var useBiometrics: Bool
        var languageCode: String
        var monthlyReviewEnabled: Bool
        var anniversaryRemindersEnabled: Bool
    }

    struct CategoryDTO: Codable {
        var uuid: UUID
        var name: String
        var symbolName: String
        var colorHex: String
        var sortOrder: Int
        var monthlyBudget: Decimal?
    }

    struct SalaryChangeDTO: Codable {
        var amount: Decimal
        var effectiveDate: Date
        var note: String
    }

    struct IncomeEntryDTO: Codable {
        var uuid: UUID
        var amount: Decimal
        var dateReceived: Date
        var note: String
    }

    struct IncomeSourceDTO: Codable {
        var uuid: UUID
        var name: String
        var type: String
        var amount: Decimal
        var frequency: String
        var paydayWeekday: Int?
        var biweeklyAnchor: Date?
        var paydayDayOfMonth: Int?
        var startDate: Date?
        var endDate: Date?
        var note: String
        var salaryChanges: [SalaryChangeDTO]
        var entries: [IncomeEntryDTO]
    }

    struct ExpenseDTO: Codable {
        var uuid: UUID
        var amount: Decimal
        var date: Date
        var note: String
        var categoryUUID: UUID?
        var billUUID: UUID?
        var receiptImageData: Data?
    }

    struct BillDTO: Codable {
        var uuid: UUID
        var name: String
        var amount: Decimal
        var frequency: String
        var dueDay: Int
        var dueMonth: Int
        var dueWeekday: Int?
        var payee: String
        var remindBeforeDays: Int
        var isRent: Bool
        var isActive: Bool
        var note: String
    }

    struct DebtPaymentDTO: Codable {
        var amount: Decimal
        var date: Date
        var note: String
    }

    struct DebtDTO: Codable {
        var uuid: UUID
        var person: String
        var direction: String
        var originalAmount: Decimal
        var date: Date
        var dueDate: Date?
        var note: String
        var isSettled: Bool
        var repayments: [DebtPaymentDTO]
    }

    struct LoanPaymentDTO: Codable {
        var amount: Decimal
        var date: Date
    }

    struct LoanDTO: Codable {
        var uuid: UUID
        var lender: String
        var principal: Decimal
        var totalRepayable: Decimal
        var installmentAmount: Decimal
        var frequency: String
        var nextDueDate: Date
        var startDate: Date
        var note: String
        var isClosed: Bool
        var payments: [LoanPaymentDTO]
    }

    struct EventDTO: Codable {
        var uuid: UUID
        var title: String
        var startDate: Date
        var durationMinutes: Int
        var isAllDay: Bool
        var location: String
        var notes: String
        var repeatRule: RepeatRule
        var reminderMinutesBefore: [Int]
    }

    struct TaskGroupDTO: Codable {
        var uuid: UUID
        var name: String
        var symbolName: String
        var colorHex: String
        var sortOrder: Int
    }

    struct TaskDTO: Codable {
        var uuid: UUID
        var title: String
        var details: String
        var dueDate: Date?
        var hasDueTime: Bool
        var priority: String
        var repeatRule: RepeatRule
        var isCompleted: Bool
        var completedAt: Date?
        var groupUUID: UUID?
    }

    struct NoteDTO: Codable {
        var uuid: UUID
        var title: String
        var body: String
        var isPinned: Bool
        var tags: [String]
        var checklist: [ChecklistItem]
        var linkedRecord: LinkedRecord?
        var createdAt: Date
        var updatedAt: Date
    }
}

// MARK: - Service

@MainActor
enum BackupService {
    enum BackupError: LocalizedError {
        case unreadable
        case unsupportedVersion(Int)

        var errorDescription: String? {
            switch self {
            case .unreadable:
                String(localized: "This file is not a LifeHub backup.")
            case .unsupportedVersion(let version):
                String(localized: "This backup (version \(version)) was made by a newer LifeHub.")
            }
        }
    }

    // MARK: Export

    static func export(context: ModelContext) throws -> Data {
        var backup = LifeHubBackup()

        let settings = AppSettings.fetchOrCreate(in: context)
        backup.settings = .init(
            currencyCode: settings.currencyCode,
            rentRemindBeforeDays: settings.rentRemindBeforeDays,
            billRemindBeforeDays: settings.billRemindBeforeDays,
            debtRemindBeforeDays: settings.debtRemindBeforeDays,
            loanRemindBeforeDays: settings.loanRemindBeforeDays,
            eventReminderMinutes: settings.eventReminderMinutes,
            reminderHour: settings.reminderHour,
            useBiometrics: settings.useBiometrics,
            languageCode: settings.languageCode,
            monthlyReviewEnabled: settings.monthlyReviewEnabled,
            anniversaryRemindersEnabled: settings.anniversaryRemindersEnabled
        )

        backup.categories = try context.fetch(FetchDescriptor<ExpenseCategory>()).map {
            .init(uuid: $0.uuid, name: $0.name, symbolName: $0.symbolName, colorHex: $0.colorHex, sortOrder: $0.sortOrder, monthlyBudget: $0.monthlyBudget)
        }

        backup.incomeSources = try context.fetch(FetchDescriptor<IncomeSource>()).map { source in
            .init(
                uuid: source.uuid,
                name: source.name,
                type: source.typeRaw,
                amount: source.amount,
                frequency: source.frequencyRaw,
                paydayWeekday: source.paydayWeekday,
                biweeklyAnchor: source.biweeklyAnchor,
                paydayDayOfMonth: source.paydayDayOfMonth,
                startDate: source.startDate,
                endDate: source.endDate,
                note: source.note,
                salaryChanges: source.sortedSalaryChanges.map {
                    .init(amount: $0.amount, effectiveDate: $0.effectiveDate, note: $0.note)
                },
                entries: source.entries.map {
                    .init(uuid: $0.uuid, amount: $0.amount, dateReceived: $0.dateReceived, note: $0.note)
                }
            )
        }

        backup.expenses = try context.fetch(FetchDescriptor<Expense>()).map {
            .init(uuid: $0.uuid, amount: $0.amount, date: $0.date, note: $0.note, categoryUUID: $0.category?.uuid, billUUID: $0.bill?.uuid, receiptImageData: $0.receiptImageData)
        }

        backup.bills = try context.fetch(FetchDescriptor<RecurringBill>()).map {
            .init(uuid: $0.uuid, name: $0.name, amount: $0.amount, frequency: $0.frequencyRaw, dueDay: $0.dueDay, dueMonth: $0.dueMonth, dueWeekday: $0.dueWeekday, payee: $0.payee, remindBeforeDays: $0.remindBeforeDays, isRent: $0.isRent, isActive: $0.isActive, note: $0.note)
        }

        backup.debts = try context.fetch(FetchDescriptor<Debt>()).map { debt in
            .init(uuid: debt.uuid, person: debt.person, direction: debt.directionRaw, originalAmount: debt.originalAmount, date: debt.date, dueDate: debt.dueDate, note: debt.note, isSettled: debt.isSettled, repayments: debt.repayments.map {
                .init(amount: $0.amount, date: $0.date, note: $0.note)
            })
        }

        backup.loans = try context.fetch(FetchDescriptor<Loan>()).map { loan in
            .init(uuid: loan.uuid, lender: loan.lender, principal: loan.principal, totalRepayable: loan.totalRepayable, installmentAmount: loan.installmentAmount, frequency: loan.frequencyRaw, nextDueDate: loan.nextDueDate, startDate: loan.startDate, note: loan.note, isClosed: loan.isClosed, payments: loan.payments.map {
                .init(amount: $0.amount, date: $0.date)
            })
        }

        backup.events = try context.fetch(FetchDescriptor<CalendarEvent>()).map {
            .init(uuid: $0.uuid, title: $0.title, startDate: $0.startDate, durationMinutes: $0.durationMinutes, isAllDay: $0.isAllDay, location: $0.location, notes: $0.notes, repeatRule: $0.repeatRule, reminderMinutesBefore: $0.reminderMinutesBefore)
        }

        backup.taskGroups = try context.fetch(FetchDescriptor<TaskGroup>()).map {
            .init(uuid: $0.uuid, name: $0.name, symbolName: $0.symbolName, colorHex: $0.colorHex, sortOrder: $0.sortOrder)
        }

        backup.tasks = try context.fetch(FetchDescriptor<TaskItem>()).map {
            .init(uuid: $0.uuid, title: $0.title, details: $0.details, dueDate: $0.dueDate, hasDueTime: $0.hasDueTime, priority: $0.priorityRaw, repeatRule: $0.repeatRule, isCompleted: $0.isCompleted, completedAt: $0.completedAt, groupUUID: $0.group?.uuid)
        }

        backup.notes = try context.fetch(FetchDescriptor<Note>()).map {
            .init(uuid: $0.uuid, title: $0.title, body: $0.body, isPinned: $0.isPinned, tags: $0.tags, checklist: $0.checklist, linkedRecord: $0.linkedRecord, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    // MARK: Restore

    /// Replaces all current data with the backup's contents.
    static func restore(from data: Data, context: ModelContext) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backup = try? decoder.decode(LifeHubBackup.self, from: data) else {
            throw BackupError.unreadable
        }
        guard backup.version <= 1 else {
            throw BackupError.unsupportedVersion(backup.version)
        }

        try wipeAll(context: context)

        // Settings
        let settings = AppSettings.fetchOrCreate(in: context)
        if let dto = backup.settings {
            settings.currencyCode = dto.currencyCode
            settings.rentRemindBeforeDays = dto.rentRemindBeforeDays
            settings.billRemindBeforeDays = dto.billRemindBeforeDays
            settings.debtRemindBeforeDays = dto.debtRemindBeforeDays
            settings.loanRemindBeforeDays = dto.loanRemindBeforeDays
            settings.eventReminderMinutes = dto.eventReminderMinutes
            settings.reminderHour = dto.reminderHour
            settings.useBiometrics = dto.useBiometrics
            settings.languageCode = dto.languageCode
            settings.monthlyReviewEnabled = dto.monthlyReviewEnabled
            settings.anniversaryRemindersEnabled = dto.anniversaryRemindersEnabled
        }

        // Categories first (expenses reference them)
        var categoriesByUUID: [UUID: ExpenseCategory] = [:]
        for dto in backup.categories {
            let category = ExpenseCategory(name: dto.name, symbolName: dto.symbolName, colorHex: dto.colorHex, sortOrder: dto.sortOrder, monthlyBudget: dto.monthlyBudget)
            category.uuid = dto.uuid
            context.insert(category)
            categoriesByUUID[dto.uuid] = category
        }

        // Bills (expenses reference them)
        var billsByUUID: [UUID: RecurringBill] = [:]
        for dto in backup.bills {
            let bill = RecurringBill(
                name: dto.name,
                amount: dto.amount,
                frequency: BillFrequency(rawValue: dto.frequency) ?? .monthly,
                dueDay: dto.dueDay,
                dueMonth: dto.dueMonth,
                dueWeekday: dto.dueWeekday,
                payee: dto.payee,
                remindBeforeDays: dto.remindBeforeDays,
                isRent: dto.isRent,
                note: dto.note
            )
            bill.uuid = dto.uuid
            bill.isActive = dto.isActive
            context.insert(bill)
            billsByUUID[dto.uuid] = bill
        }

        // Income sources with history
        for dto in backup.incomeSources {
            let source = IncomeSource(
                name: dto.name,
                type: IncomeType(rawValue: dto.type) ?? .other,
                amount: dto.amount,
                frequency: PayFrequency(rawValue: dto.frequency) ?? .monthly,
                paydayWeekday: dto.paydayWeekday,
                biweeklyAnchor: dto.biweeklyAnchor,
                paydayDayOfMonth: dto.paydayDayOfMonth,
                startDate: dto.startDate,
                endDate: dto.endDate,
                note: dto.note
            )
            source.uuid = dto.uuid
            context.insert(source)
            for change in dto.salaryChanges {
                let model = SalaryChange(amount: change.amount, effectiveDate: change.effectiveDate, note: change.note)
                model.source = source
                context.insert(model)
            }
            for entry in dto.entries {
                let model = IncomeEntry(amount: entry.amount, dateReceived: entry.dateReceived, note: entry.note, source: source)
                model.uuid = entry.uuid
                context.insert(model)
            }
        }

        // Expenses
        for dto in backup.expenses {
            let expense = Expense(
                amount: dto.amount,
                date: dto.date,
                note: dto.note,
                category: dto.categoryUUID.flatMap { categoriesByUUID[$0] },
                bill: dto.billUUID.flatMap { billsByUUID[$0] },
                receiptImageData: dto.receiptImageData
            )
            expense.uuid = dto.uuid
            context.insert(expense)
        }

        // Debts
        for dto in backup.debts {
            let debt = Debt(
                person: dto.person,
                direction: DebtDirection(rawValue: dto.direction) ?? .iOwe,
                amount: dto.originalAmount,
                date: dto.date,
                dueDate: dto.dueDate,
                note: dto.note
            )
            debt.uuid = dto.uuid
            debt.isSettled = dto.isSettled
            context.insert(debt)
            for payment in dto.repayments {
                let model = DebtPayment(amount: payment.amount, date: payment.date, note: payment.note)
                model.debt = debt
                context.insert(model)
            }
        }

        // Loans
        for dto in backup.loans {
            let loan = Loan(
                lender: dto.lender,
                principal: dto.principal,
                totalRepayable: dto.totalRepayable,
                installmentAmount: dto.installmentAmount,
                frequency: LoanFrequency(rawValue: dto.frequency) ?? .monthly,
                nextDueDate: dto.nextDueDate,
                startDate: dto.startDate,
                note: dto.note
            )
            loan.uuid = dto.uuid
            loan.isClosed = dto.isClosed
            context.insert(loan)
            for payment in dto.payments {
                let model = LoanPayment(amount: payment.amount, date: payment.date)
                model.loan = loan
                context.insert(model)
            }
        }

        // Events
        for dto in backup.events {
            let event = CalendarEvent(
                title: dto.title,
                startDate: dto.startDate,
                durationMinutes: dto.durationMinutes,
                isAllDay: dto.isAllDay,
                location: dto.location,
                notes: dto.notes,
                repeatRule: dto.repeatRule,
                reminderMinutesBefore: dto.reminderMinutesBefore
            )
            event.uuid = dto.uuid
            context.insert(event)
        }

        // Task groups then tasks
        var groupsByUUID: [UUID: TaskGroup] = [:]
        for dto in backup.taskGroups {
            let group = TaskGroup(name: dto.name, symbolName: dto.symbolName, colorHex: dto.colorHex, sortOrder: dto.sortOrder)
            group.uuid = dto.uuid
            context.insert(group)
            groupsByUUID[dto.uuid] = group
        }
        for dto in backup.tasks {
            let task = TaskItem(
                title: dto.title,
                details: dto.details,
                dueDate: dto.dueDate,
                hasDueTime: dto.hasDueTime,
                priority: TaskPriority(rawValue: dto.priority) ?? .normal,
                repeatRule: dto.repeatRule,
                group: dto.groupUUID.flatMap { groupsByUUID[$0] }
            )
            task.uuid = dto.uuid
            task.isCompleted = dto.isCompleted
            task.completedAt = dto.completedAt
            context.insert(task)
        }

        // Notes
        for dto in backup.notes {
            let note = Note(
                title: dto.title,
                body: dto.body,
                isPinned: dto.isPinned,
                tags: dto.tags,
                checklist: dto.checklist,
                linkedRecord: dto.linkedRecord
            )
            note.uuid = dto.uuid
            note.createdAt = dto.createdAt
            note.updatedAt = dto.updatedAt
            context.insert(note)
        }

        try context.save()
    }

    private static func wipeAll(context: ModelContext) throws {
        try context.delete(model: Expense.self)
        try context.delete(model: IncomeEntry.self)
        try context.delete(model: SalaryChange.self)
        try context.delete(model: IncomeSource.self)
        try context.delete(model: RecurringBill.self)
        try context.delete(model: DebtPayment.self)
        try context.delete(model: Debt.self)
        try context.delete(model: LoanPayment.self)
        try context.delete(model: Loan.self)
        try context.delete(model: CalendarEvent.self)
        try context.delete(model: TaskItem.self)
        try context.delete(model: TaskGroup.self)
        try context.delete(model: Note.self)
        try context.delete(model: ExpenseCategory.self)
        try context.save()
    }
}
