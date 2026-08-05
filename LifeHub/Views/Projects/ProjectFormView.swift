//
//  ProjectFormView.swift
//  LifeHub
//

import SwiftUI
import SwiftData
import PhotosUI

/// Add or edit a project: profile picture, name, tagline, status, start /
/// target dates, goal, description, founders, and links.
struct ProjectFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var project: Project?

    @State private var name = ""
    @State private var tagline = ""
    @State private var detail = ""
    @State private var goal = ""
    @State private var status: ProjectStatus = .idea
    @State private var startDate = Date.now
    @State private var hasTargetDate = false
    @State private var targetDate = Date.now
    @State private var founders: [ProjectFounder] = []
    @State private var links: [ProjectLink] = []

    @State private var photoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var emoji = ""
    @FocusState private var emojiFocused: Bool

    private var isEditing: Bool { project != nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                photoSection
                emojiSection
                basicsSection
                timelineSection
                goalSection
                foundersSection
                linksSection
            }
            .navigationTitle(isEditing ? "Edit Project" : "New Project")
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
            .task(id: photoItem) {
                guard let photoItem else { return }
                imageData = try? await photoItem.loadTransferable(type: Data.self)
            }
        }
    }

    // MARK: Sections

    private var photoSection: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    ProjectImage(data: imageData, name: name.isEmpty ? "?" : name, tint: status.tint, emoji: emoji)
                        .frame(width: 96, height: 96)
                        .clipShape(.circle)
                        .overlay(Circle().strokeBorder(.separator, lineWidth: 0.5))
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Text(imageData == nil ? "Add Profile Picture" : "Change Picture")
                            .font(.subheadline.weight(.medium))
                    }
                    if imageData != nil {
                        Button("Remove", role: .destructive) {
                            imageData = nil
                            photoItem = nil
                        }
                        .font(.caption)
                    }
                }
                Spacer()
            }
            .listRowBackground(Color.clear)
        } footer: {
            if imageData == nil {
                Text("No picture? Tap below and pick an emoji to use as the avatar.")
            }
        }
    }

    private var emojiSection: some View {
        Section("Emoji") {
            HStack {
                Text(emoji.isEmpty ? "🙂" : emoji)
                    .font(.title2)
                    .opacity(emoji.isEmpty ? 0.4 : 1)
                TextField("Tap to pick an emoji", text: $emoji)
                    .focused($emojiFocused)
                    .onChange(of: emoji) { _, value in
                        // Keep only the last emoji character entered.
                        if let last = value.last {
                            let s = String(last)
                            if s != value { emoji = s }
                        }
                    }
                Spacer()
                if !emoji.isEmpty {
                    Button("Clear") { emoji = "" }
                        .font(.caption)
                }
            }
        }
    }

    private var basicsSection: some View {
        Section("Project") {
            TextField("Name", text: $name)
                .textInputAutocapitalization(.words)
            TextField("Tagline (one-line pitch)", text: $tagline)
            Picker("Status", selection: $status) {
                ForEach(ProjectStatus.allCases) { status in
                    Label {
                        Text(status.titleKey)
                    } icon: {
                        Image(systemName: status.symbolName)
                    }
                    .tag(status)
                }
            }
        }
    }

    private var timelineSection: some View {
        Section("Timeline") {
            DatePicker("Start date", selection: $startDate, displayedComponents: .date)
            Toggle("Target / launch date", isOn: $hasTargetDate.animation())
            if hasTargetDate {
                DatePicker("Target", selection: $targetDate, displayedComponents: .date)
            }
        }
    }

    private var goalSection: some View {
        Section("Goal & Description") {
            TextField("Main goal", text: $goal, axis: .vertical)
                .lineLimit(1...4)
            TextField("Description", text: $detail, axis: .vertical)
                .lineLimit(3...8)
        }
    }

    private var foundersSection: some View {
        Section("Founders") {
            ForEach($founders) { $founder in
                VStack(spacing: 4) {
                    TextField("Name", text: $founder.name)
                        .textInputAutocapitalization(.words)
                    TextField("Role (e.g. CEO)", text: $founder.role)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete { founders.remove(atOffsets: $0) }

            Button {
                founders.append(ProjectFounder())
            } label: {
                Label("Add Founder", systemImage: "person.badge.plus")
            }
        }
    }

    private var linksSection: some View {
        Section("Links") {
            ForEach($links) { $link in
                VStack(spacing: 4) {
                    TextField("Label (e.g. Website)", text: $link.label)
                    TextField("URL", text: $link.urlString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete { links.remove(atOffsets: $0) }

            Button {
                links.append(ProjectLink())
            } label: {
                Label("Add Link", systemImage: "link.badge.plus")
            }
        }
    }

    // MARK: Data

    private func populate() {
        guard let project else { return }
        name = project.name
        tagline = project.tagline
        detail = project.detail
        goal = project.goal
        status = project.status
        startDate = project.startDate
        hasTargetDate = project.targetDate != nil
        targetDate = project.targetDate ?? .now
        founders = project.founders
        links = project.links
        imageData = project.imageData
        emoji = project.emoji ?? ""
    }

    private func save() {
        let cleanFounders = founders.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        let cleanLinks = links.filter { !$0.urlString.trimmingCharacters(in: .whitespaces).isEmpty }

        let target: Project
        if let project {
            target = project
        } else {
            target = Project(name: name)
            modelContext.insert(target)
        }

        target.name = name.trimmingCharacters(in: .whitespaces)
        target.tagline = tagline
        target.detail = detail
        target.goal = goal
        target.status = status
        target.startDate = startDate
        target.targetDate = hasTargetDate ? targetDate : nil
        target.founders = cleanFounders
        target.links = cleanLinks
        target.imageData = imageData
        target.emoji = emoji.isEmpty ? nil : emoji

        try? modelContext.save()
        Haptics.shared.success()
        dismiss()
    }
}

#Preview {
    ProjectFormView()
        .modelContainer(ModelContainerFactory.preview())
}
