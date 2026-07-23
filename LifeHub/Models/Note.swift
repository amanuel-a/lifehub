//
//  Note.swift
//  LifeHub
//

import Foundation
import SwiftData

/// A quick note: title, free text, optional checklist, tags, pinning,
/// and an optional link to another record (task, event, debt, loan, …).
@Model
final class Note {
    @Attribute(.unique) var uuid: UUID
    var title: String
    var body: String
    var isPinned: Bool
    var tags: [String]
    var checklist: [ChecklistItem]
    var linkedRecord: LinkedRecord?
    var createdAt: Date
    var updatedAt: Date

    init(
        title: String = "",
        body: String = "",
        isPinned: Bool = false,
        tags: [String] = [],
        checklist: [ChecklistItem] = [],
        linkedRecord: LinkedRecord? = nil
    ) {
        self.uuid = UUID()
        self.title = title
        self.body = body
        self.isPinned = isPinned
        self.tags = tags
        self.checklist = checklist
        self.linkedRecord = linkedRecord
        self.createdAt = .now
        self.updatedAt = .now
    }

    var hasChecklist: Bool { !checklist.isEmpty }

    var checklistProgress: (done: Int, total: Int) {
        (checklist.filter(\.isDone).count, checklist.count)
    }

    /// Case-insensitive match across title, body, and tags.
    func matches(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }
        let q = query.lowercased()
        return title.lowercased().contains(q)
            || body.lowercased().contains(q)
            || tags.contains { $0.lowercased().contains(q) }
            || checklist.contains { $0.text.lowercased().contains(q) }
    }
}
