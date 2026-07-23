//
//  NotificationHandler.swift
//  LifeHub
//

import Foundation
import SwiftData
import UserNotifications

/// Handles notification presentation and quick actions ("Money arrived",
/// "Mark paid", "Mark done", "Snooze") without opening the app.
@MainActor
final class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
        super.init()
    }

    // Show banners even while the app is in the foreground.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let actionID = response.actionIdentifier
        let categoryRaw = userInfo["category"] as? String ?? ""
        let uuid = (userInfo["uuid"] as? String).flatMap(UUID.init(uuidString:))
        let occurrence = (userInfo["occurrence"] as? TimeInterval).map(Date.init(timeIntervalSince1970:))
        let content = response.notification.request.content

        await MainActor.run {
            self.handle(actionID: actionID, categoryRaw: categoryRaw, uuid: uuid, occurrence: occurrence, content: content)
        }
    }

    private func handle(actionID: String, categoryRaw: String, uuid: UUID?, occurrence: Date?, content: UNNotificationContent) {
        let context = container.mainContext

        switch actionID {
        case NotificationScheduler.Action.snoozeHour.rawValue:
            snooze(content: content, seconds: 3600)
            return

        case NotificationScheduler.Action.confirmPayday.rawValue:
            if let uuid, let source = fetchIncomeSource(uuid, context: context) {
                let entry = IncomeEntry(
                    amount: source.amount,
                    dateReceived: occurrence ?? .now,
                    note: String(localized: "Confirmed from payday reminder"),
                    source: source
                )
                context.insert(entry)
            }

        case NotificationScheduler.Action.markPaid.rawValue:
            switch categoryRaw {
            case NotificationScheduler.Category.bill.rawValue:
                if let uuid, let bill = fetchBill(uuid, context: context) {
                    let category = bill.isRent ? fetchCategory(named: "Rent", context: context) : nil
                    let expense = bill.markPaid(on: .now, category: category)
                    context.insert(expense)
                }
            case NotificationScheduler.Category.loan.rawValue:
                if let uuid, let loan = fetchLoan(uuid, context: context) {
                    loan.recordInstallment()
                }
            default:
                break
            }

        case NotificationScheduler.Action.markDone.rawValue:
            if let uuid, let task = fetchTask(uuid, context: context) {
                task.complete()
            }

        default:
            // Default tap: route to the relevant tab inside the app.
            AppRouter.shared.route(toCategoryRaw: categoryRaw, uuid: uuid)
        }

        try? context.save()
        NotificationScheduler.refreshAll(context: context)
        SnapshotService.refresh(context: context)
    }

    private func snooze(content: UNNotificationContent, seconds: TimeInterval) {
        guard let mutable = content.mutableCopy() as? UNMutableNotificationContent else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(
            identifier: "snooze-\(UUID().uuidString)",
            content: mutable,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: Fetch helpers

    private func fetchIncomeSource(_ uuid: UUID, context: ModelContext) -> IncomeSource? {
        var descriptor = FetchDescriptor<IncomeSource>(predicate: #Predicate { $0.uuid == uuid })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func fetchBill(_ uuid: UUID, context: ModelContext) -> RecurringBill? {
        var descriptor = FetchDescriptor<RecurringBill>(predicate: #Predicate { $0.uuid == uuid })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func fetchLoan(_ uuid: UUID, context: ModelContext) -> Loan? {
        var descriptor = FetchDescriptor<Loan>(predicate: #Predicate { $0.uuid == uuid })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func fetchTask(_ uuid: UUID, context: ModelContext) -> TaskItem? {
        var descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.uuid == uuid })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func fetchCategory(named name: String, context: ModelContext) -> ExpenseCategory? {
        var descriptor = FetchDescriptor<ExpenseCategory>(predicate: #Predicate { $0.name == name })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
