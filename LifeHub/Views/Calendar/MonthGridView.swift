//
//  MonthGridView.swift
//  LifeHub
//

import SwiftUI

/// A clean, native-feeling month grid in a card: type-colored event dots, a
/// ring on today, a filled accent selection, and chevron month navigation.
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
        VStack(spacing: 12) {
            header

            HStack {
                ForEach(weekdayHeaders.indices, id: \.self) { index in
                    Text(weekdayHeaders[index])
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 6) {
                ForEach(cells.indices, id: \.self) { index in
                    if let day = cells[index] {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 46)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
    }

    private var header: some View {
        HStack {
            Button {
                shiftMonth(-1)
            } label: {
                chevron("chevron.left")
            }
            .accessibilityLabel(Text("Previous month"))
            Spacer()
            Text(monthStart, format: .dateTime.month(.wide).year())
                .font(.title3.weight(.bold))
                .contentTransition(.numericText())
            Spacer()
            Button {
                shiftMonth(1)
            } label: {
                chevron("chevron.right")
            }
            .accessibilityLabel(Text("Next month"))
        }
        .buttonStyle(.plain)
    }

    private func chevron(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Color.accentColor)
            .frame(width: 34, height: 34)
            .background(Color.accentColor.opacity(0.12), in: .circle)
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let isToday = day.isToday
        return Button {
            withAnimation(.spring(duration: 0.25)) { selectedDay = day }
        } label: {
            VStack(spacing: 4) {
                Text(day, format: .dateTime.day())
                    .font(.callout.weight(isSelected || isToday ? .bold : .regular))
                    .foregroundStyle(isSelected ? Color.white : (isToday ? Color.accentColor : .primary))
                    .frame(width: 34, height: 34)
                    .background {
                        if isSelected {
                            Circle().fill(Color.accentColor)
                        } else if isToday {
                            Circle().strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 1.5)
                        }
                    }
                DayDots(items: items, day: day)
            }
            .frame(height: 46)
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
