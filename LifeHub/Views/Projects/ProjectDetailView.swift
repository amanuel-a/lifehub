//
//  ProjectDetailView.swift
//  LifeHub
//

import SwiftUI
import SwiftData

/// One project: profile picture hero, status, age, goal, description,
/// founders, links, and an interactive timeline of milestones.
struct ProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var project: Project

    @State private var showingEdit = false
    @State private var showingMilestone = false
    @State private var editingMilestone: ProjectMilestone?
    @State private var showingDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                hero
                if !project.goal.isEmpty { goalCard }
                if !project.detail.isEmpty { descriptionCard }
                if !project.founders.isEmpty { foundersCard }
                if !project.links.isEmpty { linksCard }
                timelineCard
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingEdit = true
                    } label: {
                        Label("Edit Project", systemImage: "pencil")
                    }
                    Button {
                        editingMilestone = nil
                        showingMilestone = true
                    } label: {
                        Label("Add Milestone", systemImage: "calendar.badge.plus")
                    }
                    Divider()
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            ProjectFormView(project: project)
        }
        .sheet(isPresented: $showingMilestone) {
            MilestoneFormView(project: project, milestone: editingMilestone)
        }
        .confirmationDialog("Delete this project?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                modelContext.delete(project)
                try? modelContext.save()
                Haptics.shared.warning()
                dismiss()
            }
        } message: {
            Text("This removes the project and its timeline. This can't be undone.")
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 14) {
            ProjectImage(data: project.imageData, name: project.name, tint: project.status.tint, emoji: project.emoji)
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .clipShape(.rect(cornerRadius: 24))
                .overlay(alignment: .bottomLeading) {
                    StatusChip(status: project.status)
                        .padding(12)
                }

            VStack(spacing: 4) {
                Text(project.name)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                if !project.tagline.isEmpty {
                    Text(project.tagline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            HStack(spacing: 10) {
                metricPill(value: "Day \(project.dayNumber)", caption: "In progress")
                metricPill(value: project.ageDescription, caption: "Age")
                if let target = project.targetDate {
                    metricPill(value: target.relativeDayDescription, caption: "Target")
                }
            }
        }
    }

    private func metricPill(value: String, caption: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .fontDesign(.rounded)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
    }

    // MARK: Cards

    private var goalCard: some View {
        card(title: "Goal", systemImage: "target", tint: .red) {
            Text(project.goal)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var descriptionCard: some View {
        card(title: "About", systemImage: "text.alignleft", tint: .indigo) {
            Text(project.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var foundersCard: some View {
        card(title: "Founders", systemImage: "person.2.fill", tint: .teal) {
            VStack(spacing: 10) {
                ForEach(project.founders) { founder in
                    HStack(spacing: 12) {
                        SymbolBadge(symbolName: "person.fill", color: .teal, size: 36)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(founder.name)
                                .font(.subheadline.weight(.semibold))
                            if !founder.role.isEmpty {
                                Text(founder.role)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private var linksCard: some View {
        card(title: "Links", systemImage: "link", tint: .blue) {
            VStack(spacing: 10) {
                ForEach(project.links) { link in
                    if let url = link.url {
                        Link(destination: url) {
                            HStack(spacing: 12) {
                                SymbolBadge(symbolName: "safari.fill", color: .blue, size: 36)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(link.label.isEmpty ? link.urlString : link.label)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(link.urlString)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var timelineCard: some View {
        card(title: "Timeline", systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill", tint: project.status.tint) {
            VStack(alignment: .leading, spacing: 0) {
                if !project.milestones.isEmpty {
                    ProgressView(value: project.progress) {
                        Text("\(project.completedMilestoneCount) of \(project.milestones.count) done")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tint(project.status.tint)
                    .padding(.bottom, 12)
                }

                let milestones = project.sortedMilestones
                if milestones.isEmpty {
                    Text("Add milestones — funding, launch, first customer — to build a timeline.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 8)
                } else {
                    ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                        TimelineRow(
                            milestone: milestone,
                            isLast: index == milestones.count - 1,
                            toggle: { toggle(milestone) },
                            edit: {
                                editingMilestone = milestone
                                showingMilestone = true
                            }
                        )
                    }
                }

                Button {
                    editingMilestone = nil
                    showingMilestone = true
                } label: {
                    Label("Add Milestone", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: Card container

    @ViewBuilder
    private func card<Content: View>(
        title: LocalizedStringKey,
        systemImage: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage).foregroundStyle(tint)
            }
            .font(.headline)

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
    }

    // MARK: Actions

    private func toggle(_ milestone: ProjectMilestone) {
        guard let index = project.milestones.firstIndex(where: { $0.id == milestone.id }) else { return }
        project.milestones[index].isDone.toggle()
        try? modelContext.save()
        Haptics.shared.tap()
    }
}

/// One row on the vertical timeline: a connector line, a status dot, and the
/// milestone's date, title, and optional detail.
struct TimelineRow: View {
    let milestone: ProjectMilestone
    let isLast: Bool
    let toggle: () -> Void
    let edit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Button(action: toggle) {
                    Image(systemName: milestone.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(milestone.isDone ? .green : .secondary)
                }
                .buttonStyle(.plain)
                if !isLast {
                    Rectangle()
                        .fill(.separator)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(milestone.date, format: .dateTime.day().month().year())
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(milestone.title)
                    .font(.subheadline.weight(.semibold))
                    .strikethrough(milestone.isDone, color: .secondary)
                if !milestone.detail.isEmpty {
                    Text(milestone.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .onTapGesture(perform: edit)

            Spacer(minLength: 0)
        }
        .padding(.bottom, isLast ? 0 : 14)
    }
}

/// Add or edit a single milestone on a project's timeline.
struct MilestoneFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var project: Project
    var milestone: ProjectMilestone?

    @State private var title = ""
    @State private var date = Date.now
    @State private var detail = ""
    @State private var isDone = false

    private var isEditing: Bool { milestone != nil }
    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Milestone (e.g. Launched beta)", text: $title)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Toggle("Completed", isOn: $isDone)
                }
                Section("Notes") {
                    TextField("Optional detail", text: $detail, axis: .vertical)
                        .lineLimit(1...4)
                }
                if isEditing {
                    Section {
                        Button("Delete Milestone", role: .destructive, action: delete)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Milestone" : "New Milestone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
            .onAppear(perform: populate)
        }
        .presentationDetents([.medium, .large])
    }

    private func populate() {
        guard let milestone else { return }
        title = milestone.title
        date = milestone.date
        detail = milestone.detail
        isDone = milestone.isDone
    }

    private func save() {
        if let milestone, let index = project.milestones.firstIndex(where: { $0.id == milestone.id }) {
            project.milestones[index].title = title
            project.milestones[index].date = date
            project.milestones[index].detail = detail
            project.milestones[index].isDone = isDone
        } else {
            project.milestones.append(
                ProjectMilestone(title: title, date: date, detail: detail, isDone: isDone)
            )
        }
        try? modelContext.save()
        Haptics.shared.success()
        dismiss()
    }

    private func delete() {
        guard let milestone else { return }
        project.milestones.removeAll { $0.id == milestone.id }
        try? modelContext.save()
        Haptics.shared.tap()
        dismiss()
    }
}
