//
//  CalendarView.swift
//  Scoreboard
//
//  Created by David Koski on 8/30/25.
//

import Foundation
import SwiftUI

struct CalendarView: View {

    let document: ScoreboardDocument

    @Binding var items: [TableItem]
    @State private var currentDate = Date()

    @State private var selectedDay: Day?

    private var calendar: Calendar {
        Calendar.current
    }

    private var currentMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentDate)
    }

    private var daysInMonth: [Date] {
        guard let monthRange = calendar.range(of: .day, in: .month, for: currentDate),
            let startOfMonth = calendar.dateInterval(of: .month, for: currentDate)?.start
        else {
            return []
        }

        return monthRange.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }
    }

    private var firstWeekday: Int {
        guard let startOfMonth = calendar.dateInterval(of: .month, for: currentDate)?.start else {
            return 1
        }
        return calendar.component(.weekday, from: startOfMonth)
    }

    private func activities(_ daysInMonth: [Date]) -> [Day: Activity.DayRecord] {
        let days = Set(daysInMonth.map { Day($0) })
        return document.contents.activity.days
            .filter { days.contains($0.dateCode) }
            .dictionary(by: \.dateCode)
    }

    var body: some View {
        VStack(spacing: 20) {
            let daysInMonth = self.daysInMonth
            let activities = self.activities(daysInMonth)

            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.blue)
                }

                Spacer()

                HStack {
                    Text(currentMonth)
                        .font(.title2)
                        .fontWeight(.semibold)

                    let plays = activities.values.reduce(0) { $0 + $1.tablesPlayed }
                    let time = activities.values.reduce(0) { $0 + $1.secondsPlayed }
                    Text("– \(time), \(plays) games")
                }

                Spacer()

                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0
            ) {
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }

                ForEach(0 ..< (firstWeekday - 1), id: \.self) { _ in
                    Text("")
                        .frame(height: 40)
                }

                ForEach(daysInMonth, id: \.self) { date in
                    let day = Day(date)
                    CalendarDayView(
                        date: date, day: day,
                        activity: activities[day] ?? .init(day: day),
                        selectedDay: $selectedDay
                    )
                }
            }
            .padding(.horizontal)

            Spacer()

            if let selectedDay {
                DayActivity(
                    document: document,
                    day: selectedDay,
                    activity: document.contents.activity.days.first { $0.dateCode == selectedDay }
                        ?? .init(day: selectedDay)
                )
            }

            Spacer()
        }
        .padding(.top)
    }

    private func previousMonth() {
        currentDate = calendar.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate
    }

    private func nextMonth() {
        currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
    }
}

private struct CalendarDayView: View {
    let date: Date
    let day: Day
    let activity: Activity.DayRecord

    @Binding var selectedDay: Day?

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private var backgroundColor: Color {
        selectedDay == day ? .yellow : Calendar.current.isDateInToday(date) ? .blue : .clear
    }

    private var foregroundColor: Color {
        selectedDay == day ? .black : Calendar.current.isDateInToday(date) ? .white : .primary
    }

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Spacer()
                    Text(dayNumber)
                        .font(.caption)
                        .fontWeight(isToday ? .bold : .regular)
                }
                .padding(.top, 4)
                .padding(.trailing, 4)

                Spacer()
            }

            if activity.secondsPlayed > 0 {
                Text("\(activity.secondsPlayed), \(activity.tablesPlayed) games")
                    .font(.body)
            }
        }
        .foregroundColor(foregroundColor)
        .frame(maxWidth: .infinity, minHeight: 50)
        .contentShape(Rectangle())
        .onTapGesture {
            if selectedDay == day {
                selectedDay = nil
            } else {
                selectedDay = day
            }
        }
        .background(
            Rectangle()
                .fill(backgroundColor)
        )
        .overlay(
            Rectangle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

private struct DayActivity: View {

    let document: ScoreboardDocument
    let day: Day
    let activity: Activity.DayRecord

    @State private var sortOrder = [
        KeyPathComparator(\TablePlay.play.timePlayedSecs, order: .reverse)
    ]

    struct TablePlay: Identifiable {
        var id: CabinetTableId { table.id }
        let table: Table
        let score: TableScoreboard
        let scored: Bool
        let play: Activity.Play

        init?(id: WebTableId, play: Activity.Play, day: Day, document: ScoreboardDocument) {
            guard let table = document.contents[id] else { return nil }
            self.table = table
            self.score = document.contents[score: table]
            self.scored = score.entries.contains { $0.isLocal && Day($0.date) == day }
            self.play = play
        }
    }

    var tablePlays: [TablePlay] {
        activity.plays.compactMap { id, play in
            TablePlay(id: id, play: play, day: day, document: document)
        }
    }

    var body: some View {
        VStack {
            Text("\(day.date.formatted())")

            SwiftUI.Table(sortOrder: $sortOrder) {
                TableColumn("Table", value: \.table.name) { tp in
                    NavigationLink(value: tp.table) {
                        Text(tp.table.name)
                    }
                    .bold(tp.scored)
                }
                TableColumn("Played", value: \.play.timePlayedSecs) { tp in
                    Text("\(tp.play.timePlayedSecs)")
                }
            } rows: {
                ForEach(tablePlays.sorted(using: sortOrder)) { tablePlay in
                    TableRow(tablePlay)
                }
            }
        }
    }
}
