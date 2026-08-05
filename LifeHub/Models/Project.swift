//
//  Project.swift
//  LifeHub
//

import Foundation
import SwiftData
import SwiftUI

/// Where a project is in its life: from a rough idea to a launched, running
/// venture or an archived one.
enum ProjectStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case idea
    case planning
    case active
    case paused
    case launched
    case archived

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .idea: "Idea"
        case .planning: "Planning"
        case .active: "Active"
        case .paused: "Paused"
        case .launched: "Launched"
        case .archived: "Archived"
        }
    }

    var symbolName: String {
        switch self {
        case .idea: "lightbulb.fill"
        case .planning: "pencil.and.ruler.fill"
        case .active: "bolt.fill"
        case .paused: "pause.circle.fill"
        case .launched: "flag.checkered"
        case .archived: "archivebox.fill"
        }
    }

    var tint: Color {
        switch self {
        case .idea: .yellow
        case .planning: .indigo
        case .active: .green
        case .paused: .orange
        case .launched: .blue
        case .archived: .gray
        }
    }
}

/// A person who founded or co-founded the project.
struct ProjectFounder: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var name: String = ""
    var role: String = ""
}

/// A useful link for a project: website, repo, deck, social, etc.
struct ProjectLink: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var label: String = ""
    var urlString: String = ""

    /// A best-effort URL, adding `https://` when the scheme is missing.
    var url: URL? {
        let trimmed = urlString.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.contains("://") { return URL(string: trimmed) }
        return URL(string: "https://\(trimmed)")
    }
}

/// One point on a project's timeline: a milestone, launch, funding round, etc.
struct ProjectMilestone: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var title: String = ""
    var date: Date = .now
    var detail: String = ""
    var isDone: Bool = false
}

/// A project or venture the owner is building: profile picture, timeline,
/// founders, goal, links, and a full description — everything to manage it.
@Model
final class Project {
    @Attribute(.unique) var uuid: UUID
    var name: String
    /// A short one-line pitch shown under the name.
    var tagline: String
    /// The full description.
    var detail: String
    /// The main goal / mission.
    var goal: String
    var statusRaw: String
    var startDate: Date
    /// Optional target / launch date.
    var targetDate: Date?
    /// Profile picture, stored outside the database file.
    @Attribute(.externalStorage) var imageData: Data?
    /// An emoji used as the avatar when there's no picture.
    var emoji: String?
    var founders: [ProjectFounder]
    var links: [ProjectLink]
    var milestones: [ProjectMilestone]
    var createdAt: Date

    init(
        name: String,
        tagline: String = "",
        detail: String = "",
        goal: String = "",
        status: ProjectStatus = .idea,
        startDate: Date = .now,
        targetDate: Date? = nil,
        imageData: Data? = nil,
        emoji: String? = nil,
        founders: [ProjectFounder] = [],
        links: [ProjectLink] = [],
        milestones: [ProjectMilestone] = []
    ) {
        self.uuid = UUID()
        self.name = name
        self.tagline = tagline
        self.detail = detail
        self.goal = goal
        self.statusRaw = status.rawValue
        self.startDate = startDate
        self.targetDate = targetDate
        self.imageData = imageData
        self.emoji = emoji
        self.founders = founders
        self.links = links
        self.milestones = milestones
        self.createdAt = .now
    }

    var status: ProjectStatus {
        get { ProjectStatus(rawValue: statusRaw) ?? .idea }
        set { statusRaw = newValue.rawValue }
    }

    /// Milestones ordered chronologically, oldest first.
    var sortedMilestones: [ProjectMilestone] {
        milestones.sorted { $0.date < $1.date }
    }

    var completedMilestoneCount: Int {
        milestones.filter(\.isDone).count
    }

    /// 0...1 share of milestones completed; 0 when there are none.
    var progress: Double {
        guard !milestones.isEmpty else { return 0 }
        return Double(completedMilestoneCount) / Double(milestones.count)
    }

    /// How long the project has been running, e.g. "1 year, 4 months".
    var ageDescription: String {
        TenureFormatter.string(from: startDate, to: .now)
    }

    /// Which day of the project the owner is on right now (day 1 = start date).
    var dayNumber: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: startDate),
            to: calendar.startOfDay(for: .now)
        ).day ?? 0
        return max(days + 1, 1)
    }
}
