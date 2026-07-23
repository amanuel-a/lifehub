//
//  NoteEditorView.swift
//  LifeHub
//

import SwiftUI
import SwiftData

/// Create or edit a note: title, free text, checklist, tags, pinning, and
/// an optional link to another record (task, event, debt, loan, income, bill).
struct NoteEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var note: Note?

    @State private var title = ""
    @State private var bodyText = ""
    @State private var isPinned = false
    @State private var tagsText = ""
    @State private var checklist: [ChecklistItem] = []
    @State private var linkedRecord: LinkedRecord?
    @State private var showingLinkPicker = false

    private var isEditing: Bool { note != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .font(.headline)
                    TextField("Write something…", text: $bodyText, axis: .vertical)
                        .lineLimit(4...12)
                }

                Section("Checklist") {
                    ForEach($checklist) { $item in
                        HStack(spacing: 10) {
                            Button {
                                item.isDone.toggle()
                                Haptics.shared.tap()
                            } label: {
                                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.isDone ? .green : .secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(item.isDone ? Text("Mark incomplete") : Text("Mark complete"))
                            TextField("Item", text: $item.text)
                                .strikethrough(item.isDone, color: .secondary)
                        }
                    }
                    .onDelete { offsets in
                        checklist.remove(atOffsets: offsets)
                    }
                    Button {
                        checklist.append(ChecklistItem())
                    } label: {
                        Label("Add Item", systemImage: "plus.circle")
                    }
                }

                Section("Organize") {
                    Toggle(isOn: $isPinned) {
                        Label("Pinned", systemImage: "pin.fill")
                    }
                    TextField("Tags, separated by commas", text: $tagsText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section("Linked To") {
                    if let linkedRecord {
                        HStack {
                            Label(linkedRecord.label, systemImage: linkedRecord.kind.symbolName)
                            Spacer()
                            Button("Remove") {
                                self.linkedRecord = nil
                            }
                            .foregroundStyle(.red)
                        }
                    } else {
                        Button {
                            showingLinkPicker = true
                        } label: {
                            Label("Link to a task, event, or money record", systemImage: "link")
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Note" : "New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(title.isEmpty && bodyText.isEmpty && checklist.isEmpty)
                }
            }
            .sheet(isPresented: $showingLinkPicker) {
                LinkRecordPicker(selection: $linkedRecord)
            }
            .onAppear(perform: populate)
        }
    }

    private func populate() {
        guard let note else { return }
        title = note.title
        bodyText = note.body
        isPinned = note.isPinned
        tagsText = note.tags.joined(separator: ", ")
        checklist = note.checklist
        linkedRecord = note.linkedRecord
    }

    private func save() {
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
        let cleanedChecklist = checklist.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }

        let target = note ?? {
            let new = Note()
            modelContext.insert(new)
            return new
        }()

        target.title = title
        target.body = bodyText
        target.isPinned = isPinned
        target.tags = tags
        target.checklist = cleanedChecklist
        target.linkedRecord = linkedRecord
        target.updatedAt = .now

        try? modelContext.save()
        Haptics.shared.success()
        dismiss()
    }
}

/// Picks a record to link a note to.
struct LinkRecordPicker: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Binding var selection: LinkedRecord?

    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]
    @Query(sort: \CalendarEvent.startDate, order: .reverse) private var events: [CalendarEvent]
    @Query(sort: \Debt.createdAt, order: .reverse) private var debts: [Debt]
    @Query(sort: \Loan.createdAt, order: .reverse) private var loans: [Loan]
    @Query(sort: \IncomeSource.createdAt) private var sources: [IncomeSource]
    @Query(sort: \RecurringBill.createdAt) private var bills: [RecurringBill]

    var body: some View {
        NavigationStack {
            List {
                if !tasks.isEmpty {
                    Section("Tasks") {
                        ForEach(tasks.filter { !$0.isCompleted }.prefix(10)) { task in
                            linkButton(kind: .task, id: task.uuid, label: task.title)
                        }
                    }
                }
                if !events.isEmpty {
                    Section("Events") {
                        ForEach(events.prefix(10)) { event in
                            linkButton(kind: .event, id: event.uuid, label: event.title)
                        }
                    }
                }
                if !debts.isEmpty {
                    Section("Debts") {
                        ForEach(debts.prefix(10)) { debt in
                            linkButton(kind: .debt, id: debt.uuid, label: debt.person)
                        }
                    }
                }
                if !loans.isEmpty {
                    Section("Loans") {
                        ForEach(loans.prefix(10)) { loan in
                            linkButton(kind: .loan, id: loan.uuid, label: loan.lender)
                        }
                    }
                }
                if !sources.isEmpty {
                    Section("Income") {
                        ForEach(sources.prefix(10)) { source in
                            linkButton(kind: .incomeSource, id: source.uuid, label: source.name)
                        }
                    }
                }
                if !bills.isEmpty {
                    Section("Bills") {
                        ForEach(bills.prefix(10)) { bill in
                            linkButton(kind: .bill, id: bill.uuid, label: bill.name)
                        }
                    }
                }
            }
            .navigationTitle("Link Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func linkButton(kind: LinkedRecord.Kind, id: UUID, label: String) -> some View {
        Button {
            selection = LinkedRecord(kind: kind, recordID: id, label: label)
            dismiss()
        } label: {
            Label(label, systemImage: kind.symbolName)
                .foregroundStyle(.primary)
        }
    }
}
