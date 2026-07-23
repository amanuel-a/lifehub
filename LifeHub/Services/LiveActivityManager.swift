//
//  LiveActivityManager.swift
//  LifeHub
//

import Foundation
import ActivityKit
import Observation

/// Starts and ends the money-countdown Live Activity (Lock Screen +
/// Dynamic Island): "Payday in 2d 4h", "Rent due tomorrow", etc.
@MainActor
@Observable
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private(set) var currentActivity: Activity<CountdownActivityAttributes>?

    var isTracking: Bool { currentActivity != nil }

    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Starts (or replaces) the countdown activity.
    func startCountdown(
        kind: CountdownActivityAttributes.Kind,
        title: String,
        amount: Decimal,
        currencyCode: String,
        targetDate: Date
    ) {
        guard areActivitiesEnabled else { return }
        Task {
            await endCurrent()
            let attributes = CountdownActivityAttributes(
                kind: kind,
                title: title,
                amount: amount,
                currencyCode: currencyCode
            )
            let state = CountdownActivityAttributes.ContentState(targetDate: targetDate)
            let content = ActivityContent(state: state, staleDate: targetDate.addingTimeInterval(3600))
            do {
                currentActivity = try Activity.request(attributes: attributes, content: content)
            } catch {
                currentActivity = nil
            }
        }
    }

    /// Marks the countdown finished (shows a brief "done" state, then ends).
    func completeCurrent() {
        guard let activity = currentActivity else { return }
        Task {
            var state = activity.content.state
            state.isDone = true
            let content = ActivityContent(state: state, staleDate: .now.addingTimeInterval(300))
            await activity.update(content)
            await activity.end(content, dismissalPolicy: .after(.now.addingTimeInterval(120)))
            currentActivity = nil
        }
    }

    func endCurrent() async {
        // End anything from a previous run as well.
        for activity in Activity<CountdownActivityAttributes>.activities {
            await activity.end(activity.content, dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }

    func stopTracking() {
        Task { await endCurrent() }
    }
}
