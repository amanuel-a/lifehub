//
//  NotesView.swift
//  LifeHub
//

import SwiftUI
import SwiftData

/// Quick notes: pinned first, native search across titles, text, tags, and
/// checklists, with tag filtering.
struct NotesView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]

    @State private var searchText = ""
    @State private var selectedTag: String?
    @State private var showingEditor = false
    @State private var editingNote: Note?

    private var filtered: [Note] {
        notes
            .filter { searchText.isEmpty || $0.matches(searchText) }
            .filter { selectedTag == nil || $0.tags.contains(selectedTag!) }
    }

    private var pinned: [Note] { filtered.filter(\.isPinned) }
    private var others: [Note] { filtered.filter { !$0.isPinned } }

    private var allTags: [String] {
        Array(Set(notes.flatMap(\.tags))).sorted()
    }

    var body: some View {
        NavigationStack {
            List {
                if !allTags.isEmpty {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(allTags, id: \.self) { tag in
                                    TagChip(tag: tag, isSelected: selectedTag == tag) {
                                        withAnimation(.spring(duration: 0.25)) {
                                            selectedTag = selectedTag == tag ? nil : tag
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 4, trailing: 16))
                    }
                }

                if filtered.isEmpty {
                    EmptyStateView(
                        titleKey: "No Notes",
                        messageKey: "Capture quick notes, checklists, and thoughts — pin the important ones.",
                        symbolName: "note.text"
                    )
                    .listRowBackground(Color.clear)
                }

                if !pinned.isEmpty {
                    Section("Pinned") {
                        ForEach(pinned) { note in
                            noteRow(note)
                        }
                    }
                }

                if !others.isEmpty {
                    Section(pinned.isEmpty ? "" : "Notes") {
                        ForEach(others) { note in
                            noteRow(note)
                        }
                    }
                }
            }
            .navigationTitle("Notes")
            .searchable(text: $searchText, prompt: "Search notes and tags")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingEditor = true
                    } label: {
                        Label("New Note", systemImage: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                NoteEditorView()
            }
            .sheet(item: $editingNote) { note in
                NoteEditorView(note: note)
            }
        }
    }

    private func noteRow(_ note: Note) -> some View {
        Button {
            editingNote = note
        } label: {
            NoteRow(note: note)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading) {
            Button {
                note.isPinned.toggle()
                note.updatedAt = .now
                try? modelContext.save()
                Haptics.shared.tap()
            } label: {
                Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                modelContext.delete(note)
                try? modelContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

/// One note row: title, preview, checklist progress, tags, link chip.
struct NoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .accessibilityLabel(Text("Pinned"))
                }
                Text(note.title.isEmpty ? String(localized: "Untitled") : note.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Spacer()
                Text(note.updatedAt, format: .dateTime.day().month())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !note.body.isEmpty {
                Text(note.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 6) {
                if note.hasChecklist {
                    let progress = note.checklistProgress
                    Label("\(progress.done)/\(progress.total)", systemImage: "checklist")
                        .font(.caption)
                        .foregroundStyle(progress.done == progress.total ? .green : .secondary)
                }
                if let link = note.linkedRecord {
                    Label(link.label, systemImage: link.kind.symbolName)
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .lineLimit(1)
                }
                ForEach(note.tags.prefix(3), id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// A tappable tag filter chip.
struct TagChip: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("#\(tag)")
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.tertiarySystemFill), in: .capsule)
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
