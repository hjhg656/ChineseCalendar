import SwiftUI

struct ContentView: View {
    @AppStorage(AppSettings.themeColorKey, store: AppSettings.sharedDefaults) private var themeColorName = "red"
    @AppStorage(AppSettings.fontSizeKey, store: AppSettings.sharedDefaults) private var fontSizeName = "medium"
    @AppStorage(AppSettings.boldTextKey, store: AppSettings.sharedDefaults) private var boldText = false
    @AppStorage(AppSettings.showWeekNumbersKey, store: AppSettings.sharedDefaults) private var showWeekNumbers = true
    @AppStorage(AppSettings.weekOnlyKey, store: AppSettings.sharedDefaults) private var weekOnly = false
    @AppStorage(AppSettings.hideOtherMonthDaysKey, store: AppSettings.sharedDefaults) private var hideOtherMonthDays = false
    @AppStorage(AppSettings.showHolidaysKey, store: AppSettings.sharedDefaults) private var showHolidays = true

    @State private var displayedDate: Date = Date()
    @State private var selectedDate: Date = Date()
    @State private var showSettings = false
    @StateObject private var eventStore = EventStore()

    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]

    private var themeColor: Color { AppSettings.themeColor(named: themeColorName) }
    private var fontScale: CGFloat { AppSettings.fontScale(named: fontSizeName) }

    /// 当前要显示的周：只看本周时只显示一周，否则显示整月。
    private var weeks: [[Date]] {
        weekOnly ? [ChineseCalendarHelper.weekContaining(displayedDate)]
                 : ChineseCalendarHelper.monthWeeks(for: displayedDate)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 今天
                todayCard

                // 月份 / 周切换
                HStack {
                    Button { step(by: -1) } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                    Text(ChineseCalendarHelper.monthTitle(for: displayedDate))
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    Button { step(by: 1) } label: {
                        Image(systemName: "chevron.right")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 8)

                // 星期头
                HStack(spacing: 0) {
                    if showWeekNumbers {
                        Text("周")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 36)
                    }
                    ForEach(weekdays, id: \.self) { w in
                        Text(w)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 6)

                // 日历格子（按周分行）
                VStack(spacing: 4) {
                    ForEach(weeks, id: \.self) { week in
                        HStack(spacing: 0) {
                            if showWeekNumbers, let first = week.first {
                                Text("第\(ChineseCalendarHelper.weekOfYear(for: first))周")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36)
                            }
                            ForEach(week, id: \.self) { day in
                                dayCell(day)
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)

                // 选中那天的详情
                dayDetail
                    .padding(.top, 12)

                Spacer()
            }
            .padding(.horizontal, 8)
            .navigationTitle("中国日历")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("今天") {
                        displayedDate = Date()
                        selectedDate = Date()
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(eventStore: eventStore)
            }
            .tint(themeColor)
            .onAppear {
                eventStore.refreshStatus()
                eventStore.loadEvents(for: displayedDate)
                Task { await eventStore.loadReminders(for: selectedDate) }
            }
            .onChange(of: displayedDate) { _, newValue in
                eventStore.loadEvents(for: newValue)
            }
            .onChange(of: selectedDate) { _, newValue in
                Task { await eventStore.loadReminders(for: newValue) }
            }
        }
    }

    private func step(by value: Int) {
        if weekOnly {
            displayedDate = ChineseCalendarHelper.addingDay(value * 7, to: displayedDate)
        } else {
            displayedDate = ChineseCalendarHelper.addingMonth(value, to: displayedDate)
        }
    }

    // MARK: - 今天

    private var todayCard: some View {
        let today = Date()
        return VStack(spacing: 4) {
            Text(ChineseCalendarHelper.fullGregorianString(for: today))
                .font(.headline)
            Text(ChineseCalendarHelper.lunarFullString(for: today))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if showHolidays, let statutory = ChineseCalendarHelper.statutoryDay(for: today) {
                switch statutory {
                case .holiday(let name):
                    Text("\(name) · 放假")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                case .workday:
                    Text("调休上班")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
            } else if let festival = ChineseCalendarHelper.festival(for: today) {
                Text(festival)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding(.vertical, 8)
    }

    // MARK: - 格子

    private func dayCell(_ day: Date) -> some View {
        let inMonth = ChineseCalendarHelper.month(of: day) == ChineseCalendarHelper.month(of: displayedDate)
        if hideOtherMonthDays && !inMonth && !weekOnly {
            return AnyView(Color.clear.frame(maxWidth: .infinity, minHeight: 52))
        }
        let isToday = ChineseCalendarHelper.isToday(day)
        let isSelected = ChineseCalendarHelper.isSameDay(day, selectedDate)
        let statutory = showHolidays ? ChineseCalendarHelper.statutoryDay(for: day) : nil
        let festival = ChineseCalendarHelper.festival(for: day)
        let smallText: String
        if case .holiday(let name) = statutory {
            smallText = name
        } else if let festival {
            smallText = festival
        } else {
            smallText = ChineseCalendarHelper.lunarShortString(for: day)
        }
        let hasEvents = !eventStore.events(on: day).isEmpty
        return AnyView(
            Button {
                selectedDate = day
                if !inMonth && !weekOnly { displayedDate = day }
            } label: {
                VStack(spacing: 1) {
                    Text("\(ChineseCalendarHelper.gregorian.component(.day, from: day))")
                        .font(.system(size: 17 * fontScale))
                        .fontWeight((isToday || boldText) ? .bold : .regular)
                    Text(smallText)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundStyle((statutory != nil || festival != nil) ? Color.red : Color.secondary)
                    if hasEvents {
                        Circle()
                            .fill(themeColor)
                            .frame(width: 5, height: 5)
                    } else {
                        Color.clear.frame(width: 5, height: 5)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    isSelected ? themeColor.opacity(0.2) :
                        isToday ? Color.red.opacity(0.12) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isToday ? Color.red : Color.clear, lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
                    if case .holiday = statutory {
                        Text("休")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.red)
                            .padding(2)
                    } else if case .workday = statutory {
                        Text("班")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.orange)
                            .padding(2)
                    }
                }
                .opacity(inMonth || weekOnly ? 1 : 0.35)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
        )
    }

    // MARK: - 详情

    private var dayDetail: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(ChineseCalendarHelper.fullGregorianString(for: selectedDate)) · 第\(ChineseCalendarHelper.weekOfYear(for: selectedDate))周")
                .font(.headline)
            Text("农历  \(ChineseCalendarHelper.lunarFullString(for: selectedDate))")
                .font(.subheadline)
            if showHolidays, let statutory = ChineseCalendarHelper.statutoryDay(for: selectedDate) {
                switch statutory {
                case .holiday(let name):
                    Text("法定节假日  \(name) · 放假")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                case .workday:
                    Text("调休上班")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
            } else if let festival = ChineseCalendarHelper.festival(for: selectedDate) {
                Text("节日  \(festival)")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }

            // 系统日历的日程
            let events = eventStore.events(on: selectedDate)
            if eventStore.calendarAccess == .granted {
                if events.isEmpty {
                    Text("这天没有系统日程")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(events, id: \.eventIdentifier) { event in
                        HStack {
                            Text(EventStore.timeText(for: event))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(event.title ?? "（无标题）")
                                .font(.subheadline)
                        }
                    }
                }
            } else {
                Button("读取系统日历和提醒事项") {
                    Task {
                        await eventStore.requestAccess()
                        eventStore.loadEvents(for: displayedDate)
                        await eventStore.loadReminders(for: selectedDate)
                    }
                }
                .font(.footnote)
            }

            // 当天到期的提醒
            if eventStore.remindersAccess == .granted {
                ForEach(eventStore.remindersForDay, id: \.calendarItemIdentifier) { reminder in
                    HStack {
                        Image(systemName: "bell")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                        Text(reminder.title ?? "（无标题）")
                            .font(.subheadline)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ContentView()
}
