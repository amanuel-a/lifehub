//
//  EventFormView.swift
//  LifeHub
//

import SwiftUI
import SwiftData

/// Create or edit an event: title, date/time, duration, location, notes,
/// repeat rule, and reminder offsets.
struct EventFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var event: CalendarEvent?
    var defaultDate: Date = .now

    @State private var title = ""
    @State private var isAllDay = false
    @State private var startDate = Date.now
    @State private var durationMinutes = 60
    @State private var location = ""
    @State private var notes = ""
    @State private var repeatRule = RepeatRule.never
    @State private var reminders: Set<Int> = [30]

    private var isEditing: Bool { event != nil }

    private let reminderOptions: [(minutes: Int, label: LocalizedStringKey)] = [
        (0, "At time of event"),
        (10, "10 minutes before"),
        (30, "30 minutes before"),
        (60, "1 hour before"),
        (1_440, "1 day before"),
        (4_320, "3 days before")
    ]

    private let durationOptions = [15, 30, 45, 60, 90, 120, 180, 240, 480]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextField("Location (optional)", text: $location)
                }

                Section("When") {
                    Toggle("All-day", isOn: $isAllDay.animation())
                    DatePicker(
                        "Starts",
                        selection: $startDate,
                        displayedComponents: isAllDay ? .date : [.date, .hourAndMinute]
                    )
                    if !isAllDay {
                        Picker("Duration", selection: $durationMinutes) {
                            ForEach(durationOptions, id: \.self) { minutes in
                                Text(durationLabel(minutes)).tag(minutes)
                            }
                        }
                    }
                    RepeatRulePicker(rule: $repeatRule)
                }

                Section("Reminders") {
                    ForEach(reminderOptions, id: \.minutes) { option in
                        Toggle(isOn: binding(for: option.minutes)) {
                            Text(option.label)
                        }
                    }
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                if isEditing {
                    Section {
                        Button("Delete Event", role: .destructive) {
                            if let event {
                                modelContext.delete(event)
                                finish()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Event" : "New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: populate)
        }
    }

    private func binding(for minutes: Int) -> Binding<Bool> {
        Binding(
            get: { reminders.contains(minutes) },
            set: { isOn in
                if isOn { reminders.insert(minutes) } else { reminders.remove(minutes) }
            }
        )
    }

    private func durationLabel(_ minutes: Int) -> String {
        minutes < 60
            ? String(localized: "\(minutes) min")
            : String(localized: "\(minutes / 60) h\(minutes % 60 == 0 ? "" : " \(minutes % 60) min")")
    }

    private func populate() {
        if let event {
            title = event.title
            isAllDay = event.isAllDay
            startDate = event.startDate
            durationMinutes = event.durationMinutes
            location = event.location
            notes = event.notes
            repeatRule = event.repeatRule
            reminders = Set(event.reminderMinutesBefore)
        } else {
            // Default to the next full hour on the selected day.
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: .now) + 1
            startDate = calendar.date(bySettingHour: min(hour, 23), minute: 0, second: 0, of: defaultDate) ?? defaultDate
        }
    }

    private func save() {
        let target = event ?? {
            let new = CalendarEvent(title: title, startDate: startDate)
            modelContext.insert(new)
            return new
        }()

        target.title = title.trimmingCharacters(in: .whitespaces)
        target.isAllDay = isAllDay
        target.startDate = startDate
        target.durationMinutes = isAllDay ? 0 : durationMinutes
        target.location = location
        target.notes = notes
        target.repeatRule = repeatRule
        target.reminderMinutesBefore = reminders.sorted()

        finish()
    }

    private func finish() {
        try? modelContext.save()
        Haptics.shared.success()
        NotificationScheduler.refreshAll(context: modelContext)
        SnapshotService.refresh(context: modelContext)
        dismiss()
    }
}

/// Repeat rule editing shared by events and tasks: frequency, interval,
/// and optional weekday selection ("richer recurring rules").
struct RepeatRulePicker: View {
    @Binding var rule: RepeatRule

    var body: some View {
        Picker("Repeat", selection: $rule.frequency) {
            ForEach(RepeatRule.Frequency.allCases) { frequency in
                Text(frequency.titleKey).tag(frequency)
            }
        }

        if rule.frequency != .never {
            Stepper(value: $rule.interval, in: 1...30) {
                Text(intervalLabel)
            }
        }

        if rule.frequency == .weekly {
            WeekdayToggleRow(selection: $rule.weekdays)
        }
    }

    private var intervalLabel: String {
        let n = rule.interval
        switch rule.frequency {
        case .never: return ""
        case .daily: return n == 1 ? String(localized: "Every day") : String(localized: "Every \(n) days")
        case .weekly: return n == 1 ? String(localized: "Every week") : String(localized: "Every \(n) weeks")
        case .monthly: return n == 1 ? String(localized: "Every month") : String(localized: "Every \(n) months")
        case .yearly: return n == 1 ? String(localized: "Every year") : String(localized: "Every \(n) years")
        }
    }
}

/// Circular weekday toggles (S M T W T F S).
struct WeekdayToggleRow: View {
    @Binding var selection: Set<Int>

    private var symbols: [String] {
        Calendar.current.veryShortStandaloneWeekdaySymbols
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...7, id: \.self) { weekday in
                let isOn = selection.contains(weekday)
                Button {
                    Haptics.shared.tap()
                    if isOn { selection.remove(weekday) } else { selection.insert(weekday) }
                } label: {
                    Text(symbols[weekday - 1])
                        .font(.caption.weight(.semibold))
                        .frame(width: 34, height: 34)
                        .background(isOn ? Color.accentColor : Color(.tertiarySystemFill), in: .circle)
                        .foregroundStyle(isOn ? .white : .primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(Calendar.current.standaloneWeekdaySymbols[weekday - 1]))
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}
