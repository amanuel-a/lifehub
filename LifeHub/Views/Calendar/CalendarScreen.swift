//
//  CalendarScreen.swift
//  LifeHub
//

import SwiftUI
import SwiftData

/// The unified calendar: month, week, day, and agenda-list views showing
/// events, task deadlines, paydays, rent day, and debt/loan due dates —
/// color-coded, filterable by type, and presented in clean cards.
struct CalendarScreen: View {
    private enum ViewMode: String, CaseIterable, Identifiable {
        case month, week, day, list
        var id: String { rawValue }

        var titleKey: LocalizedStringKey {
            switch self {
            case .month: "Month"
            case .week: "Week"
            case .day: "Day"
            case .list: "List"
            }
        }
    }

    @Environment(\.modelContext) private var modelContext

    @Query private var settingsList: [AppSettings]

    @State private var mode: ViewMode = .month
    @State private var selectedDay = Date.now.startOfDay
    @State private var showingEventForm = false
    @State private var editingEvent: CalendarEvent?
    /// Type filter; empty means "show everything".
    @State private var activeKinds: Set<AgendaKind> = []
    /// Cached agenda items for the visible range, rebuilt on change.
    @State private var visibleItems: [AgendaItem] = []

    private let calendar = Calendar.current

    /// Items after applying the type filter.
    private var filteredItems: [AgendaItem] {
        activeKinds.isEmpty ? visibleItems : visibleItems.filter { activeKinds.contains($0.kind) }
    }

    /// Types actually present in the loaded window, for the filter chips.
    private var presentKinds: [AgendaKind] {
        let present = Set(visibleItems.map(\.kind))
        return AgendaKind.allCases.filter { present.contains($0) }
    }

    private var dayItems: [AgendaItem] {
        filteredItems.filter { calendar.isDate($0.date, inSameDayAs: selectedDay) }
    }

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
                .padding(.bottom, 10)

                if !presentKinds.isEmpty {
                    filterChips
                        .padding(.bottom, 10)
                }

                ScrollView {
                    VStack(spacing: 16) {
                        switch mode {
                        case .month:
                            MonthGridView(selectedDay: $selectedDay, items: filteredItems)
                            singleDayAgenda
                        case .week:
                            WeekStripView(selectedDay: $selectedDay, items: filteredItems)
                            singleDayAgenda
                        case .day:
                            dayPickerCard
                            singleDayAgenda
                        case .list:
                            agendaTimeline
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
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

    // MARK: Filter chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(presentKinds) { kind in
                    KindChip(kind: kind, isOn: activeKinds.contains(kind)) {
                        Haptics.shared.tap()
                        withAnimation(.snappy(duration: 0.2)) {
                            if activeKinds.contains(kind) {
                                activeKinds.remove(kind)
                            } else {
                                activeKinds.insert(kind)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: Day mode

    private var dayPickerCard: some View {
        VStack(spacing: 12) {
            HStack {
                Button { shiftDay(-1) } label: {
                    Image(systemName: "chevron.left").font(.body.weight(.semibold))
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(selectedDay, format: .dateTime.weekday(.wide))
                        .font(.headline)
                    Text(selectedDay, format: .dateTime.day().month(.wide).year())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { shiftDay(1) } label: {
                    Image(systemName: "chevron.right").font(.body.weight(.semibold))
                }
            }
            .buttonStyle(.borderless)

            DatePicker("Day", selection: $selectedDay, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
    }

    // MARK: Single-day agenda (month / week / day modes)

    private var singleDayAgenda: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(selectedDay, format: .dateTime.weekday(.wide).day().month())
                    .font(.headline)
                if selectedDay.isToday {
                    Text("Today")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor, in: .capsule)
                }
                Spacer()
                if !dayItems.isEmpty {
                    Text("\(dayItems.count)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)

            if dayItems.isEmpty {
                emptyCard(message: "Nothing scheduled.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(dayItems.enumerated()), id: \.element.id) { index, item in
                        CategoryEventRow(item: item) { open(item) }
                        if index < dayItems.count - 1 {
                            Divider().padding(.leading, 18)
                        }
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
            }
        }
    }

    // MARK: Agenda list (list mode) — grouped by day with date badges

    private var agendaTimeline: some View {
        let upcoming = filteredItems
            .filter { $0.date >= selectedDay }
            .sorted { $0.date < $1.date }
        let groups = Dictionary(grouping: upcoming) { calendar.startOfDay(for: $0.date) }
        let days = groups.keys.sorted()

        return VStack(spacing: 14) {
            if days.isEmpty {
                emptyCard(message: "No upcoming items. Tap + to add an event.")
            } else {
                ForEach(days, id: \.self) { day in
                    DayGroupRow(
                        day: day,
                        items: groups[day] ?? [],
                        open: open
                    )
                }
            }
        }
    }

    private func emptyCard(message: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles").font(.title3).foregroundStyle(.blue)
            Text(message).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
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

    private func shiftDay(_ value: Int) {
        if let next = calendar.date(byAdding: .day, value: value, to: selectedDay) {
            withAnimation(.spring(duration: 0.25)) { selectedDay = next }
        }
    }

    /// Rebuilds the agenda for the visible range (a padded month window),
    /// merging in synced device / Google calendar events when enabled.
    private func rebuild() {
        let start = calendar.date(byAdding: .day, value: -42, to: selectedDay) ?? selectedDay
        let end = calendar.date(byAdding: .day, value: 60, to: selectedDay) ?? selectedDay
        let range = DateInterval(start: start, end: end)
        var items = AgendaService.items(in: range, context: modelContext)
        let syncEnabled = settingsList.first?.syncDeviceCalendars ?? false
        items += CalendarSyncService.shared.agendaItems(in: range, enabled: syncEnabled)
        visibleItems = items.sorted { lhs, rhs in
            lhs.date != rhs.date ? lhs.date < rhs.date : lhs.title < rhs.title
        }
    }
}

// MARK: - Filter chip

/// A pill that toggles a type filter, filled with the type's color when on.
struct KindChip: View {
    let kind: AgendaKind
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: kind.symbolName)
                    .font(.caption2.weight(.bold))
                Text(kind.titleKey)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(isOn ? .white : kind.tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                if isOn {
                    Capsule().fill(kind.tint)
                } else {
                    Capsule().fill(kind.tint.opacity(0.12))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - Category event row

/// One event styled after the reference: a colored accent bar, a colored
/// category label, the title, and a trailing time / amount.
struct CategoryEventRow: View {
    let item: AgendaItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(item.kind.tint)
                    .frame(width: 4)
                    .frame(maxHeight: .infinity)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.kind.titleKey)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(item.kind.tint)
                        .textCase(.uppercase)
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let subtitle = item.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    if let amount = item.amount {
                        AmountText(amount: amount)
                            .font(.subheadline.weight(.semibold))
                    }
                    if item.hasTime {
                        Text(item.date, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 10)
            .frame(maxHeight: 60)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Agenda day group (list mode)

/// One day in the agenda list: a left date badge and the day's events.
struct DayGroupRow: View {
    let day: Date
    let items: [AgendaItem]
    let open: (AgendaItem) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            DateBadge(day: day)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    CategoryEventRow(item: item) { open(item) }
                    if index < items.count - 1 {
                        Divider().padding(.leading, 18)
                    }
                }
            }
            .padding(.horizontal, 12)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
        }
    }
}

/// The left-side date card in the agenda list — accent-filled for today.
struct DateBadge: View {
    let day: Date

    private var isToday: Bool { day.isToday }

    var body: some View {
        VStack(spacing: 1) {
            Text(day, format: .dateTime.month(.abbreviated))
                .font(.caption2.weight(.bold))
                .textCase(.uppercase)
            Text(day, format: .dateTime.day())
                .font(.title2.weight(.bold))
                .fontDesign(.rounded)
            Text(day, format: .dateTime.weekday(.abbreviated))
                .font(.caption2)
                .opacity(0.8)
        }
        .foregroundStyle(isToday ? .white : .primary)
        .frame(width: 58, height: 74)
        .background {
            if isToday {
                RoundedRectangle(cornerRadius: 16).fill(Color.accentColor)
            } else {
                RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(day, format: .dateTime.weekday(.wide).day().month()))
    }
}

// MARK: - Week strip

/// Seven tappable day columns with type-colored dots, in a clean card.
struct WeekStripView: View {
    @Binding var selectedDay: Date
    let items: [AgendaItem]

    private let calendar = Calendar.current

    private var weekDays: [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: selectedDay) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(weekDays, id: \.self) { day in
                let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
                Button {
                    withAnimation(.spring(duration: 0.25)) { selectedDay = day }
                } label: {
                    VStack(spacing: 6) {
                        Text(day, format: .dateTime.weekday(.narrow))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(day, format: .dateTime.day())
                            .font(.body.weight(isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? Color.white : (day.isToday ? Color.accentColor : .primary))
                            .frame(width: 36, height: 36)
                            .background {
                                if isSelected {
                                    Circle().fill(Color.accentColor)
                                } else if day.isToday {
                                    Circle().strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 1.5)
                                }
                            }
                        DayDots(items: items, day: day)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(day, format: .dateTime.weekday(.wide).day().month()))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
    }
}

/// Up to four colored dots summarizing a day's item types.
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
            if seen.count == 4 { break }
        }
        return seen
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(kinds) { kind in
                Circle()
                    .fill(kind.tint)
                    .frame(width: 5.5, height: 5.5)
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}
