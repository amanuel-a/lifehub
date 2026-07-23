//
//  CalendarScreen.swift
//  LifeHub
//

import SwiftUI
import SwiftData

/// The unified calendar: month, week, and day views showing events, task
/// deadlines, paydays, rent day, and debt/loan due dates — color-coded.
struct CalendarScreen: View {
    private enum ViewMode: String, CaseIterable, Identifiable {
        case month, week, day
        var id: String { rawValue }

        var titleKey: LocalizedStringKey {
            switch self {
            case .month: "Month"
            case .week: "Week"
            case .day: "Day"
            }
        }
    }

    @Environment(\.modelContext) private var modelContext

    @State private var mode: ViewMode = .month
    @State private var selectedDay = Date.now.startOfDay
    @State private var showingEventForm = false
    @State private var editingEvent: CalendarEvent?
    /// Cached agenda items for the visible range, rebuilt on change.
    @State private var visibleItems: [AgendaItem] = []

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $mode.animation(.spring(duration: 0.3))) {
                    ForEach(ViewMode.allCases) { mode in
                        Text(mode.titleKey).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                switch mode {
                case .month:
                    MonthGridView(
                        selectedDay: $selectedDay,
                        items: visibleItems
                    )
                case .week:
                    WeekStripView(selectedDay: $selectedDay, items: visibleItems)
                case .day:
                    DatePicker("Day", selection: $selectedDay, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .padding(.horizontal)
                }

                dayAgendaList
            }
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingEventForm = true
                    } label: {
                        Label("Add Event", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Today") {
                        withAnimation(.spring(duration: 0.3)) {
                            selectedDay = Date.now.startOfDay
                        }
                    }
                    .disabled(selectedDay.isToday)
                }
            }
            .sheet(isPresented: $showingEventForm, onDismiss: rebuild) {
                EventFormView(defaultDate: selectedDay)
            }
            .sheet(item: $editingEvent, onDismiss: rebuild) { event in
                EventFormView(event: event)
            }
            .onAppear(perform: rebuild)
            .onChange(of: selectedDay) { rebuild() }
            .onChange(of: mode) { rebuild() }
        }
    }

    // MARK: Day agenda

    private var dayAgendaList: some View {
        List {
            Section {
                let dayItems = visibleItems.filter { calendar.isDate($0.date, inSameDayAs: selectedDay) }
                if dayItems.isEmpty {
                    Text("Nothing on \(selectedDay, format: .dateTime.weekday(.wide).day().month()).")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(dayItems) { item in
                        Button {
                            open(item)
                        } label: {
                            AgendaRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text(selectedDay, format: .dateTime.weekday(.wide).day().month())
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.visible)
    }

    private func open(_ item: AgendaItem) {
        switch item.kind {
        case .event:
            guard let uuid = item.recordUUID else { return }
            var descriptor = FetchDescriptor<CalendarEvent>(predicate: #Predicate { $0.uuid == uuid })
            descriptor.fetchLimit = 1
            editingEvent = try? modelContext.fetch(descriptor).first
        case .task:
            AppRouter.shared.selectedTab = .tasks
        default:
            AppRouter.shared.selectedTab = .money
        }
    }

    /// Rebuilds the agenda for the visible range (a padded month window).
    private func rebuild() {
        let start = calendar.date(byAdding: .day, value: -42, to: selectedDay) ?? selectedDay
        let end = calendar.date(byAdding: .day, value: 42, to: selectedDay) ?? selectedDay
        visibleItems = AgendaService.items(in: DateInterval(start: start, end: end), context: modelContext)
    }
}

// MARK: - Week strip

/// Seven tappable day columns with type-colored dots.
struct WeekStripView: View {
    @Binding var selectedDay: Date
    let items: [AgendaItem]

    private let calendar = Calendar.current

    private var weekDays: [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: selectedDay) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(weekDays, id: \.self) { day in
                let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
                Button {
                    withAnimation(.spring(duration: 0.25)) { selectedDay = day }
                } label: {
                    VStack(spacing: 6) {
                        Text(day, format: .dateTime.weekday(.narrow))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(day, format: .dateTime.day())
                            .font(.body.weight(isSelected ? .bold : .regular))
                            .foregroundStyle(isSelected ? Color.white : (day.isToday ? Color.accentColor : .primary))
                            .frame(width: 34, height: 34)
                            .background(isSelected ? Color.accentColor : Color.clear, in: .circle)
                        DayDots(items: items, day: day)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(day, format: .dateTime.weekday(.wide).day().month()))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 6)
    }
}

/// Up to three colored dots summarizing a day's item types.
struct DayDots: View {
    let items: [AgendaItem]
    let day: Date

    private var kinds: [AgendaKind] {
        let calendar = Calendar.current
        let dayKinds = items
            .filter { calendar.isDate($0.date, inSameDayAs: day) }
            .map(\.kind)
        var seen: [AgendaKind] = []
        for kind in dayKinds where !seen.contains(kind) {
            seen.append(kind)
            if seen.count == 3 { break }
        }
        return seen
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(kinds) { kind in
                Circle()
                    .fill(kind.tint)
                    .frame(width: 5, height: 5)
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}
