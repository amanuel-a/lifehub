//
//  MonthGridView.swift
//  LifeHub
//

import SwiftUI

/// A native-feeling month grid with type-colored dots and swipe-free
/// month navigation via chevrons.
struct MonthGridView: View {
    @Binding var selectedDay: Date
    let items: [AgendaItem]

    private let calendar = Calendar.current

    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDay)) ?? selectedDay
    }

    /// All cells shown: leading blanks + the month's days.
    private var cells: [Date?] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7
        var result: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for day in dayRange {
            result.append(calendar.date(byAdding: .day, value: day - 1, to: monthStart))
        }
        return result
    }

    private var weekdayHeaders: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    var body: some View {
        VStack(spacing: 8) {
            header

            HStack {
                ForEach(weekdayHeaders.indices, id: \.self) { index in
                    Text(weekdayHeaders[index])
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 6) {
                ForEach(cells.indices, id: \.self) { index in
                    if let day = cells[index] {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    private var header: some View {
        HStack {
            Button {
                shiftMonth(-1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel(Text("Previous month"))
            Spacer()
            Text(monthStart, format: .dateTime.month(.wide).year())
                .font(.headline)
                .contentTransition(.numericText())
            Spacer()
            Button {
                shiftMonth(1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel(Text("Next month"))
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 4)
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        return Button {
            withAnimation(.spring(duration: 0.25)) { selectedDay = day }
        } label: {
            VStack(spacing: 3) {
                Text(day, format: .dateTime.day())
                    .font(.callout.weight(isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? Color.white : (day.isToday ? Color.accentColor : .primary))
                    .frame(width: 32, height: 32)
                    .background(isSelected ? Color.accentColor : Color.clear, in: .circle)
                DayDots(items: items, day: day)
            }
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(day, format: .dateTime.weekday(.wide).day().month()))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func shiftMonth(_ value: Int) {
        if let next = calendar.date(byAdding: .month, value: value, to: selectedDay) {
            withAnimation(.spring(duration: 0.3)) { selectedDay = next }
        }
    }
}
