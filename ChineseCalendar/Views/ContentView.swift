import SwiftUI
import AudioToolbox
import UIKit
import Combine

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 动效统一走这两个：减弱动态效果打开时全部关掉（iOS 规范：提供一条同样可用的无动画路径）。
    /// 翻月/点日期/选年月用 0.3s，滑杆与提示用 0.25s——不同距离的过渡不用同一个时长。
    private var slideAnimation: Animation? { reduceMotion ? nil : .easeInOut(duration: 0.3) }
    private var quickAnimation: Animation? { reduceMotion ? nil : .easeInOut(duration: 0.25) }

    @AppStorage(AppSettings.showWeekKey, store: AppSettings.sharedDefaults) private var showWeek = false
    @AppStorage(AppSettings.useSingleLineModeKey, store: AppSettings.sharedDefaults) private var weekOnly = false
    @AppStorage(AppSettings.hideOtherDaysKey, store: AppSettings.sharedDefaults) private var hideOtherDays = false
    @AppStorage(AppSettings.hideHolidaysKey, store: AppSettings.sharedDefaults) private var hideHolidays = false
    @AppStorage(AppSettings.hideSystemEventsKey, store: AppSettings.sharedDefaults) private var hideSystemEvents = false
    @AppStorage(AppSettings.useSysEvtColorKey, store: AppSettings.sharedDefaults) private var useSysEvtColor = true
    @AppStorage(AppSettings.silentModeKey, store: AppSettings.sharedDefaults) private var silentMode = false
    @AppStorage(AppSettings.todayModeKey, store: AppSettings.sharedDefaults) private var todayMode = true
    @AppStorage(AppSettings.useBlackFontKey, store: AppSettings.sharedDefaults) private var useBlackFont = false
    @AppStorage(AppSettings.shouldShowSubTitleKey, store: AppSettings.sharedDefaults) private var showSubTitle = true
    @AppStorage(AppSettings.fontScaleKey, store: AppSettings.sharedDefaults) private var fontScale = 1.0
    @AppStorage(AppSettings.calendarWidthScaleKey, store: AppSettings.sharedDefaults) private var widthScale = 1.0
    @AppStorage(AppSettings.calendarHeightScaleKey, store: AppSettings.sharedDefaults) private var heightScale = 1.0
    @AppStorage(AppSettings.positionScaleKey, store: AppSettings.sharedDefaults) private var positionScale = 0.5

    @State private var displayedDate: Date = Date()
    @State private var monthDirection: Int = 1
    @State private var selectedDate: Date = Date()
    @State private var detailDate: Date? = nil
    @State private var showSettings = false
    @State private var settingsSection = "color"
    @State private var showDatePicker = false
    @State private var showAddEvent = false
    @State private var showPushUpdate = false
    @State private var toast: String? = nil
    @State private var didApplyTodayMode = false
    @StateObject private var eventStore = EventStore()

    // 颜色：用 @AppStorage 观察，设置里改完立刻刷新（之前是静态读，改完不刷新）。
    // 深色版（...Dark）没有编辑入口，沿用浅色值，和之前一致。
    @AppStorage("appThemeColor", store: AppSettings.sharedDefaults) private var themeColorHex = "#EA545D"
    @AppStorage("calendarGridColor", store: AppSettings.sharedDefaults) private var gridColorHex = "#404040"
    @AppStorage("calendarWeekendColor", store: AppSettings.sharedDefaults) private var weekendColorHex = "#404040"
    @AppStorage("calendarHolidayColor", store: AppSettings.sharedDefaults) private var holidayColorHex = "#708090"
    @AppStorage("calendarTodayColor", store: AppSettings.sharedDefaults) private var todayColorHex = "#EA545D"
    @AppStorage("calendarEventColor", store: AppSettings.sharedDefaults) private var eventColorHex = "#0EA5E9"
    @AppStorage("calendarWorkColor", store: AppSettings.sharedDefaults) private var workColorHex = "#E67E22"
    @AppStorage("calendarFreeColor", store: AppSettings.sharedDefaults) private var freeColorHex = "#EA545D"

    private var themeColor: Color { Color(hex: themeColorHex) }
    private var gridColor: Color { Color(hex: gridColorHex) }
    private var weekendColor: Color { Color(hex: weekendColorHex) }
    private var holidayColor: Color { Color(hex: holidayColorHex) }
    private var todayColor: Color { Color(hex: todayColorHex) }
    private var eventColor: Color { Color(hex: eventColorHex) }
    private var workColor: Color { Color(hex: workColorHex) }
    private var freeColor: Color { Color(hex: freeColorHex) }

    /// 当前要显示的周：只看本周时只显示一周，否则显示整月。
    private var weeks: [[Date]] {
        weekOnly ? [ChineseCalendarHelper.weekContaining(displayedDate)]
                 : ChineseCalendarHelper.monthWeeks(for: displayedDate)
    }

    /// 月历翻页的键：同月（周）不重建，换月（周）才滑进滑出。
    private var gridKey: String {
        let g = ChineseCalendarHelper.gregorian
        let y = g.component(.year, from: displayedDate)
        if weekOnly { return "\(y)-w\(ChineseCalendarHelper.weekOfYear(for: displayedDate))" }
        return "\(y)-\(g.component(.month, from: displayedDate))"
    }

    var body: some View {
        VStack(spacing: 0) {
            if showDatePicker {
                // 年月选择器：内嵌面板（小历不是弹窗，底部四行还留着）
                YearMonthPickerView(displayedDate: $displayedDate, selectedDate: $selectedDate, isPresented: $showDatePicker)
                    .padding(.top, 8 + (positionScale - 0.5) * 60)
                    .padding(.horizontal, panelPadding)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                // 标题行：2026 / 11 · 46
                titleRow
                    .padding(.top, 8 + (positionScale - 0.5) * 60)

                // 星期头
                HStack(spacing: 0) {
                    if showWeek {
                        Text("周")
                            .font(.system(size: AppSettings.weekdayFontSize))
                            .foregroundStyle(AppSettings.sublineGrey)
                            .frame(width: 36)
                    }
                    ForEach(ChineseCalendarHelper.weekdaySymbols(), id: \.self) { w in
                        Text(w)
                            .font(.system(size: AppSettings.weekdayFontSize))
                            .foregroundStyle(AppSettings.sublineGrey)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, panelPadding)
                .contentShape(Rectangle())
                .onTapGesture {
                    if detailDate != nil {
                        withAnimation(quickAnimation) { detailDate = nil }
                    }
                }

                // 日详情态：三行蓝标签卡 + 事件列表，月历淡显在下面
                if let detail = detailDate {
                    DayDetailView(date: detail, onAddEvent: { showAddEvent = true }, eventStore: eventStore)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // 日历格子（单例常驻，换月时上下滑进滑出；日详情打开时淡显）
                calendarGrid
                    .padding(.horizontal, panelPadding)
                    .gesture(
                        DragGesture(minimumDistance: 30)
                            .onEnded { value in
                                guard detailDate == nil else { return }
                                if value.translation.width < -30 { step(by: 1) }
                                else if value.translation.width > 30 { step(by: -1) }
                            }
                    )
            }

            // 点空白处关掉日详情（原版点哪里都能关）
            Color.clear
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onTapGesture {
                    if detailDate != nil {
                        withAnimation(quickAnimation) { detailDate = nil }
                    }
                }

            // 底部四行入口
            bottomRows
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .statusBar(hidden: true)
        .tint(themeColor)
        // 小历的动效：周视图收起/展开、字号与面板尺寸变化都平滑过渡。
        .animation(slideAnimation, value: weekOnly)
        .animation(quickAnimation, value: fontScale)
        .animation(quickAnimation, value: widthScale)
        .animation(quickAnimation, value: heightScale)
        .animation(quickAnimation, value: positionScale)
        .sheet(isPresented: $showSettings, onDismiss: {
            eventStore.loadEvents(for: displayedDate)
            eventStore.loadReminderDays(for: displayedDate)
        }) {
            SettingsView(eventStore: eventStore, initialSection: settingsSection)
        }
        .sheet(isPresented: $showAddEvent) {
            AddEventView(date: selectedDate, eventStore: eventStore) {
                eventStore.loadEvents(for: displayedDate)
            }
        }
        .alert("更新节日推送", isPresented: $showPushUpdate) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text("内置节假日表已是最新，覆盖 2025–2027 年（按国务院办公厅放假通知）。2028 年的安排公布后需要更新 App 里的表。")
        }
        .overlay(alignment: .top) {
            if let toast {
                Text(toast)
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground), in: Capsule())
                    .shadow(radius: 4)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(quickAnimation, value: toast)
        .onAppear {
            eventStore.refreshStatus()
            eventStore.loadEvents(for: displayedDate)
            eventStore.loadReminderDays(for: displayedDate)
            Task { await eventStore.loadReminders(for: selectedDate) }
            // “默认展开今日”：第一次打开就展开今天的日详情（只做一次，之后不打扰）。
            if todayMode && !didApplyTodayMode {
                didApplyTodayMode = true
                detailDate = selectedDate
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ChineseCalendarShortcut"))) { note in
            handleShortcut(note.userInfo?["action"] as? String ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ChineseCalendarDeepLink"))) { note in
            if let date = note.userInfo?["date"] as? Date {
                monthDirection = date >= displayedDate ? 1 : -1
                withAnimation(slideAnimation) {
                    displayedDate = date
                    selectedDate = date
                    detailDate = date
                }
            }
        }
        .onChange(of: displayedDate) { _, newValue in
            eventStore.loadEvents(for: newValue)
            eventStore.loadReminderDays(for: newValue)
        }
        .onChange(of: selectedDate) { _, newValue in
            Task { await eventStore.loadReminders(for: newValue) }
        }
        .task(id: toast) {
            if toast != nil {
                try? await Task.sleep(for: .seconds(1.5))
                toast = nil
            }
        }
    }

    // MARK: - 标题行

    private var titleRow: some View {
        HStack {
            arrowButton(systemName: "chevron.left") { step(by: -1) } longPress: { stepYear(by: -1) }
            Spacer()
            Text("\(ChineseCalendarHelper.monthTitle(for: displayedDate)) · \(ChineseCalendarHelper.weekOfYear(for: displayedDate))")
                .font(.system(size: AppSettings.titleFontSize))
                .fontWeight(.bold)
                .foregroundStyle(AppSettings.ink)
                .id(gridKey)
                .transition(.opacity)
                .gesture(
                    TapGesture(count: 2).onEnded { goToday() }
                        .exclusively(before: TapGesture(count: 1).onEnded { withAnimation(slideAnimation) { showDatePicker = true } })
                )
            Spacer()
            arrowButton(systemName: "chevron.right") { step(by: 1) } longPress: { stepYear(by: 1) }
        }
        .padding(.horizontal, 8)
    }

    private func arrowButton(systemName: String, tap: @escaping () -> Void, longPress: @escaping () -> Void) -> some View {
        Image(systemName: systemName)
            .font(.title3)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .gesture(
                LongPressGesture(minimumDuration: 0.5).onEnded { _ in longPress() }
                    .exclusively(before: TapGesture().onEnded { tap() })
            )
    }

    private func step(by value: Int) {
        playClick()
        monthDirection = value > 0 ? 1 : -1
        withAnimation(slideAnimation) {
            if weekOnly {
                displayedDate = ChineseCalendarHelper.addingDay(value * 7, to: displayedDate)
            } else {
                displayedDate = ChineseCalendarHelper.addingMonth(value, to: displayedDate)
            }
        }
    }

    private func stepYear(by value: Int) {
        playClick()
        monthDirection = value > 0 ? 1 : -1
        withAnimation(slideAnimation) {
            displayedDate = ChineseCalendarHelper.addingMonth(value * 12, to: displayedDate)
        }
    }

    private func goToday() {
        monthDirection = Date() >= displayedDate ? 1 : -1
        withAnimation(slideAnimation) {
            displayedDate = Date()
            selectedDate = Date()
            detailDate = nil
        }
    }

    private func playClick() {
        if !silentMode { AudioServicesPlaySystemSound(1104) }
    }

    private var panelPadding: CGFloat {
        max(0, (1.0 - widthScale) * 30 + 4)
    }

    // MARK: - 日历格子

    private var calendarGrid: some View {
        VStack(spacing: 4) {
            ForEach(weeks, id: \.self) { week in
                HStack(spacing: 0) {
                    if showWeek, let first = week.first {
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
        .opacity(detailDate == nil ? 1 : 0.45)
        // 小历的面板上下移动画：往后翻从下面滑进来，往前翻从上面滑进来。
        .id(gridKey)
        .transition(.asymmetric(
            insertion: .move(edge: monthDirection > 0 ? .bottom : .top).combined(with: .opacity),
            removal: .move(edge: monthDirection > 0 ? .top : .bottom).combined(with: .opacity)))
        .animation(slideAnimation, value: detailDate)
    }

    private func dayCell(_ day: Date) -> some View {
        let info = ChineseCalendarHelper.dayInfo(for: day)
        let inMonth = ChineseCalendarHelper.month(of: day) == ChineseCalendarHelper.month(of: displayedDate)
        if hideOtherDays && !inMonth && !weekOnly {
            return AnyView(Color.clear.frame(maxWidth: .infinity, minHeight: AppSettings.dayCellHeight * heightScale))
        }
        let isToday = ChineseCalendarHelper.isToday(day)
        let isSelected = detailDate != nil && ChineseCalendarHelper.isSameDay(day, selectedDate)
        let isDetail = detailDate != nil

        // 数字色：周末用周末色，平日用一般日期色，非本月淡显。
        var numberColor: Color = info.isWeekend ? weekendColor : gridColor
        if !inMonth { numberColor = numberColor.opacity(0.4) }
        // 副行：有节日时用节日色，农历小字用实测浅灰（小历的副行就是浅灰，不是深色）。
        var subColor: Color = info.hasHoliday ? holidayColor : AppSettings.sublineGrey
        if hideHolidays { subColor = AppSettings.sublineGrey }
        let subText: String
        if !showSubTitle {
            subText = ""
        } else if hideHolidays {
            subText = ChineseCalendarHelper.lunarShortString(for: day)
        } else if let name = info.displayName {
            subText = name
        } else {
            subText = ChineseCalendarHelper.lunarShortString(for: day)
        }

        // 事件小圆点颜色。
        let dotColors = hideSystemEvents ? [] : eventStore.eventDotColors(
            on: day, useSysColor: useSysEvtColor,
            fallback: UIColor(eventColor))
        let hasReminderDot = !hideSystemEvents && eventStore.hasReminders(on: day)

        return AnyView(
            Button {
                playClick()
                // 再点一次已打开的那天就收起详情（小历没有关闭按钮）。
                if detailDate != nil && ChineseCalendarHelper.isSameDay(day, selectedDate) {
                    withAnimation(slideAnimation) { detailDate = nil }
                    return
                }
                if !inMonth && !weekOnly { monthDirection = day > displayedDate ? 1 : -1 }
                withAnimation(slideAnimation) {
                    selectedDate = day
                    if !inMonth && !weekOnly { displayedDate = day }
                    detailDate = day
                }
                Task { await eventStore.loadReminders(for: day) }
            } label: {
                VStack(spacing: 1) {
                    Text("\(ChineseCalendarHelper.gregorian.component(.day, from: day))")
                        .font(.system(size: AppSettings.dayNumberFontSize * fontScale, weight: (isToday || isSelected || useBlackFont) ? .bold : .regular))
                        .foregroundStyle(isToday && !isDetail ? .white : (isSelected ? .black : numberColor))
                        .frame(width: AppSettings.todayCircleSize, height: AppSettings.todayCircleSize)
                        .background(
                            isToday
                            ? (isDetail ? todayColor.opacity(0.3) : todayColor)
                            : Color.clear,
                            in: Circle()
                        )
                    if showSubTitle {
                        Text(subText)
                            .font(.system(size: AppSettings.sublineFontSize * fontScale, weight: .light))
                            .lineLimit(1)
                            .foregroundStyle(subColor)
                    }
                    // 事件小圆点
                    HStack(spacing: 3) {
                        ForEach(0..<min(dotColors.count, 3), id: \.self) { i in
                            Circle()
                                .fill(Color(uiColor: dotColors[i]))
                                .frame(width: 5, height: 5)
                        }
                        if hasReminderDot {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 5, height: 5)
                        }
                        if dotColors.isEmpty && !hasReminderDot {
                            Color.clear.frame(width: 5, height: 5)
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: AppSettings.dayCellHeight * heightScale)
                .overlay(alignment: .topTrailing) {
                    if !hideHolidays {
                        if info.worktime == 2 {
                            Text("休")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(inMonth ? freeColor : freeColor.opacity(0.5))
                                .padding(2)
                        } else if info.worktime == 1 {
                            Text("班")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(inMonth ? workColor : workColor.opacity(0.5))
                                .padding(2)
                        }
                    }
                }
                .opacity(inMonth || weekOnly ? 1 : 0.35)
            }
            .buttonStyle(.plain)
        )
    }

    // MARK: - 底部四行

    private var bottomRows: some View {
        VStack(spacing: 0) {
            bottomRow(icon: "paintbrush", title: "颜色") { openSettings("color") }
            bottomRow(icon: "ruler", title: "布局") { openSettings("layout") }
            bottomRow(icon: "heart", title: "偏好设置") { openSettings("style") }
            bottomRow(icon: "ellipsis.circle", title: "其他") { openSettings("other") }
        }
    }

    private func bottomRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 28)
                    .foregroundStyle(.secondary)
                Text(title)
                    .foregroundStyle(AppSettings.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func openSettings(_ section: String) {
        playClick()
        settingsSection = section
        showSettings = true
    }

    // MARK: - 快捷操作

    private func handleShortcut(_ action: String) {
        switch action {
        case "copyToday":
            copyDaySummary(Date())
        case "showToday":
            goToday()
        case "updatePush":
            showPushUpdate = true
        default:
            break
        }
    }

    private func copyDaySummary(_ date: Date) {
        let info = ChineseCalendarHelper.dayInfo(for: date)
        var text = "\(ChineseCalendarHelper.fullGregorianString(for: date)) 第\(info.week)周\n"
        text += "农历 \(ChineseCalendarHelper.lunarFullString(for: date))"
        if let name = info.displayName { text += "\n\(name)" }
        UIPasteboard.general.string = text
        toast = "已复制"
    }
}

// MARK: - 日详情（点某日后，月历淡显）

struct DayDetailView: View {
    let date: Date
    let onAddEvent: () -> Void
    @ObservedObject var eventStore: EventStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var quickAnimation: Animation? { reduceMotion ? nil : .easeInOut(duration: 0.25) }

    private var info: ChineseCalendarHelper.DayInfo { ChineseCalendarHelper.dayInfo(for: date) }

    var body: some View {
        VStack(spacing: 10) {
            // 三行蓝标签卡
            infoCard(tag: "公历", text: "\(ChineseCalendarHelper.gregorian.component(.month, from: date))月\(ChineseCalendarHelper.gregorian.component(.day, from: date))日(\(ChineseCalendarHelper.relativeDayText(for: date))) 第\(info.week)周") {
                UIPasteboard.general.string = "\(ChineseCalendarHelper.fullGregorianString(for: date)) 第\(info.week)周"
            }
            infoCard(tag: "农历", text: "\(ChineseCalendarHelper.stemBranchYear(for: date).dropLast())(\(info.zodiac))年 \(ChineseCalendarHelper.lunarDateString(for: date))") {
                UIPasteboard.general.string = ChineseCalendarHelper.lunarFullString(for: date)
            }
            Button(action: onAddEvent) {
                HStack(spacing: 8) {
                    Text("事件")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppSettings.tagBlue, in: RoundedRectangle(cornerRadius: 5))
                    Text("+ 添加事件")
                        .font(.subheadline)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            // 节日 / 事件 / 提醒列表（有内容才显示，没内容什么都不显示）
            if hasEventList {
                eventList
            }
        }
        .padding()
        .animation(quickAnimation, value: date)
    }

    private var hasEventList: Bool {
        !info.detailNames.isEmpty || !eventStore.events(on: date).isEmpty || !eventStore.remindersForDay.isEmpty
    }

    private func infoCard(tag: String, text: String, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text(tag)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppSettings.tagBlue, in: RoundedRectangle(cornerRadius: 5))
                Text(text)
                    .font(.subheadline)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private var eventList: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 节日
            ForEach(info.detailNames, id: \.self) { name in
                HStack {
                    Circle().fill(AppSettings.measuredRed).frame(width: 6, height: 6)
                    Text(name).font(.subheadline)
                }
            }
            // 系统日程
            if eventStore.calendarAccess == .granted {
                ForEach(eventStore.events(on: date), id: \.eventIdentifier) { event in
                    HStack {
                        Circle()
                            .fill(event.calendar.cgColor.map { Color(cgColor: $0) } ?? AppSettings.tagBlue)
                            .frame(width: 6, height: 6)
                        Text(EventStore.timeText(for: event))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(event.title ?? "（无标题）")
                            .font(.subheadline)
                        Spacer()
                        Button(role: .destructive) {
                            try? eventStore.deleteEvent(event)
                            eventStore.loadEvents(for: date)
                        } label: {
                            Image(systemName: "trash")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            // 提醒事项
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
    }
}

// MARK: - 年月选择器

struct YearMonthPickerView: View {
    @Binding var displayedDate: Date
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    private var slideAnimation: Animation? { reduceMotion ? nil : .easeInOut(duration: 0.3) }
    private var themeColor: Color { AppSettings.color(forKey: "appThemeColor", colorScheme: colorScheme) }

    @State private var pickedYear: Int
    @State private var pickedMonth: Int

    init(displayedDate: Binding<Date>, selectedDate: Binding<Date>, isPresented: Binding<Bool>) {
        _displayedDate = displayedDate
        _selectedDate = selectedDate
        _isPresented = isPresented
        let now = displayedDate.wrappedValue
        _pickedYear = State(initialValue: ChineseCalendarHelper.gregorian.component(.year, from: now))
        _pickedMonth = State(initialValue: ChineseCalendarHelper.gregorian.component(.month, from: now))
    }

    private let years = Array(2016...2036)

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 20) {
                // 年份网格（3 列）
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(years, id: \.self) { year in
                        Button {
                            pickedYear = year
                        } label: {
                            VStack(spacing: 2) {
                                Text("\(year)")
                                    .font(.headline)
                                    .foregroundStyle(AppSettings.ink)
                                // 当前年下方小红三角（截图里 2026 的字是深色的，红三角标的是“今年”）
                                if year == ChineseCalendarHelper.gregorian.component(.year, from: Date()) {
                                    Image(systemName: "triangle.fill")
                                        .font(.system(size: 7))
                                        .foregroundStyle(themeColor)
                                } else {
                                    Color.clear.frame(height: 7)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .animation(slideAnimation, value: pickedYear)
                // 月份网格（2 列）
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(1...12, id: \.self) { month in
                        Button {
                            pickedMonth = month
                        } label: {
                            Text("\(month)月")
                                .font(.headline)
                                .foregroundStyle(pickedMonth == month ? .white : AppSettings.ink)
                                .frame(width: 52, height: 52)
                                .background(pickedMonth == month ? themeColor : Color.clear, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .animation(slideAnimation, value: pickedMonth)
            }
            HStack {
                Spacer()
                Button("取消") { isPresented = false }
                    .font(.headline)
                Button("确定") {
                    // 保持当月的几号（不要重置成 1 号，否则标题的周数会跳到月初那周）
                    let currentDay = ChineseCalendarHelper.gregorian.component(.day, from: displayedDate)
                    let firstOfMonth = ChineseCalendarHelper.gregorian.date(from: DateComponents(year: pickedYear, month: pickedMonth, day: 1))
                    let daysInMonth = firstOfMonth.flatMap { ChineseCalendarHelper.gregorian.range(of: .day, in: .month, for: $0)?.count } ?? 31
                    let day = min(currentDay, daysInMonth)
                    if let date = ChineseCalendarHelper.gregorian.date(from: DateComponents(year: pickedYear, month: pickedMonth, day: day)) {
                        withAnimation(slideAnimation) {
                            displayedDate = date
                            selectedDate = date
                        }
                    }
                    isPresented = false
                }
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(themeColor, lineWidth: 1))
            }
        }
        .padding()
    }
}

// MARK: - 添加事件

struct AddEventView: View {
    let date: Date
    @ObservedObject var eventStore: EventStore
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var allDay = false
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var errorText: String? = nil

    init(date: Date, eventStore: EventStore, onSaved: @escaping () -> Void) {
        self.date = date
        self.eventStore = eventStore
        self.onSaved = onSaved
        let start = ChineseCalendarHelper.gregorian.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
        _startDate = State(initialValue: start)
        _endDate = State(initialValue: start.addingTimeInterval(3600))
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("事件标题", text: $title)
                Toggle("全天", isOn: $allDay)
                DatePicker("开始", selection: $startDate, displayedComponents: allDay ? [.date] : [.date, .hourAndMinute])
                if !allDay {
                    DatePicker("结束", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                }
                if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("添加事件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else {
                            errorText = "先写个标题"
                            return
                        }
                        do {
                            try eventStore.addEvent(title: name, start: startDate, end: max(endDate, startDate), allDay: allDay)
                            onSaved()
                            dismiss()
                        } catch {
                            errorText = "保存失败：\(error.localizedDescription)"
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
