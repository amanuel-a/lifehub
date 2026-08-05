//
//  ProjectsView.swift
//  LifeHub
//

import SwiftUI
import SwiftData

/// The Projects tab: manage every venture you're building — each with a
/// profile picture, timeline, founders, goal, links, and description.
struct ProjectsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]

    @State private var showingForm = false

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            Group {
                if projects.isEmpty {
                    EmptyStateView(
                        titleKey: "No Projects Yet",
                        messageKey: "Add a venture you're building — track its timeline, founders, goal, links, and everything in one place.",
                        symbolName: "square.stack.3d.up.fill"
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(projects) { project in
                                NavigationLink {
                                    ProjectDetailView(project: project)
                                } label: {
                                    ProjectTile(project: project)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                    .background(Color(.systemGroupedBackground).ignoresSafeArea())
                }
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingForm = true
                    } label: {
                        Label("Add Project", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingForm) {
                ProjectFormView()
            }
        }
    }
}

/// A card in the projects grid: profile image header, name, status, progress.
struct ProjectTile: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProjectImage(data: project.imageData, name: project.name, tint: project.status.tint, emoji: project.emoji)
                .frame(height: 110)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(alignment: .topLeading) {
                    StatusChip(status: project.status)
                        .padding(8)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(project.name)
                    .font(.headline)
                    .lineLimit(1)
                if !project.tagline.isEmpty {
                    Text(project.tagline)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !project.milestones.isEmpty {
                    ProgressView(value: project.progress)
                        .tint(project.status.tint)
                    Text("\(project.completedMilestoneCount)/\(project.milestones.count) milestones")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text(project.ageDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.separator.opacity(0.4), lineWidth: 0.5))
        .accessibilityElement(children: .combine)
    }
}

/// A profile image for a project: a photo if set, otherwise a chosen emoji,
/// otherwise a colored monogram of the name — all on a tinted gradient.
struct ProjectImage: View {
    let data: Data?
    let name: String
    let tint: Color
    var emoji: String? = nil

    var body: some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                ZStack {
                    LinearGradient(
                        colors: [tint.opacity(0.85), tint.opacity(0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    if let emoji, !emoji.isEmpty {
                        Text(emoji)
                            .font(.system(size: side * 0.5))
                    } else {
                        Text(monogram)
                            .font(.system(size: side * 0.42, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }

    private var monogram: String {
        let letters = name
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }
}

/// A small pill showing a project's status with its color and icon.
struct StatusChip: View {
    let status: ProjectStatus

    var body: some View {
        Label {
            Text(status.titleKey)
        } icon: {
            Image(systemName: status.symbolName)
        }
        .font(.caption2.weight(.bold))
        .labelStyle(.titleAndIcon)
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.tint, in: .capsule)
        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
    }
}

#Preview {
    ProjectsView()
        .modelContainer(ModelContainerFactory.preview())
}
