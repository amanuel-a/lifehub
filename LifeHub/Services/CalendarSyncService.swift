//
//  CalendarSyncService.swift
//  LifeHub
//

import Foundation
import EventKit

/// Bridges the device's calendars into LifeHub's agenda using EventKit.
///
/// Any account added in iOS Settings → Calendar → Accounts is included — so a
/// Google (or Outlook / iCloud) account synced there surfaces its meetings
/// here automatically, with no separate login. Access is read-only: LifeHub
/// never modifies the user's calendars.
@MainActor
final class CalendarSyncService {
    static let shared = CalendarSyncService()

    private let store = EKEventStore()

    private init() {}

    /// Whether LifeHub currently has permission to read calendar events.
    var isAuthorized: Bool {
        if #available(iOS 17.0, *) {
            return EKEventStore.authorizationStatus(for: .event) == .fullAccess
        } else {
            return EKEventStore.authorizationStatus(for: .event) == .authorized
        }
    }

    /// Requests read access to calendar events. Returns whether it was granted.
    func requestAccess() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                return try await store.requestFullAccessToEvents()
            } else {
                return try await store.requestAccess(to: .event)
            }
        } catch {
            return false
        }
    }

    /// Device-calendar events inside `range`, mapped into agenda items.
    /// Returns an empty array when sync is off or unauthorized.
    func agendaItems(in range: DateInterval, enabled: Bool) -> [AgendaItem] {
        guard enabled, isAuthorized else { return [] }
        let predicate = store.predicateForEvents(withStart: range.start, end: range.end, calendars: nil)
        return store.events(matching: predicate).compactMap { event in
            guard let start = event.startDate else { return nil }
            let title = event.title?.isEmpty == false ? event.title! : String(localized: "Busy")
            let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines)
            let subtitle = (location?.isEmpty == false ? location : event.calendar?.title)
            return AgendaItem(
                id: "ek-\(event.calendarItemIdentifier)-\(Int(start.timeIntervalSince1970))",
                kind: .event,
                date: start,
                hasTime: !event.isAllDay,
                title: title,
                subtitle: subtitle,
                amount: nil,
                recordUUID: nil
            )
        }
    }
}
