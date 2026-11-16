import EventKit
import Foundation
import UIKit

/// 读系统日历和提醒事项（EventKit）。
/// 只读已有日程和提醒；添加事件走用户在日详情里点的“+ 添加事件”，
/// 删除事件走事件行的左滑删除；不会改别的日程，也不会上传。
/// 要用户在设置里点了“允许”才会去读；拒绝了就什么都不显示。
@MainActor
final class EventStore: ObservableObject {

    enum AccessState {
        case unknown        // 还没问过
        case granted        // 已允许
        case denied         // 拒绝了，去系统设置里才能再开
    }

    private let store = EKEventStore()

    @Published var calendarAccess: AccessState = .unknown
    @Published var remindersAccess: AccessState = .unknown

    /// 某天有哪些系统日程，key 是那天的 0 点。
    @Published var eventsByDay: [Date: [EKEvent]] = [:]

    /// 选中那天到期的未完成提醒。
    @Published var remindersForDay: [EKReminder] = []

    /// 选中那天到期的提醒里，有几号有提醒（用来在月视图画提醒小点）。
    @Published var reminderDays: Set<Date> = []

    /// 事件管理里隐藏掉的日历 / 提醒事项列表（存 identifier）。
    private let hiddenCalendarsKey = "hiddenCalendarIDs"
    private let hiddenReminderListsKey = "hiddenReminderListIDs"

    var hiddenCalendarIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: hiddenCalendarsKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: hiddenCalendarsKey) }
    }

    var hiddenReminderListIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: hiddenReminderListsKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: hiddenReminderListsKey) }
    }

    init() {
        refreshStatus()
    }

    func refreshStatus() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: calendarAccess = .granted
        case .denied, .restricted: calendarAccess = .denied
        default: calendarAccess = .unknown
        }
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess: remindersAccess = .granted
        case .denied, .restricted: remindersAccess = .denied
        default: remindersAccess = .unknown
        }
    }

    /// 弹系统授权框，问用户让不让读日历和提醒事项。
    func requestAccess() async {
        do {
            let eventsOK = try await store.requestFullAccessToEvents()
            calendarAccess = eventsOK ? .granted : .denied
        } catch {
            calendarAccess = .denied
        }
        do {
            let remindersOK = try await store.requestFullAccessToReminders()
            remindersAccess = remindersOK ? .granted : .denied
        } catch {
            remindersAccess = .denied
        }
    }

    // MARK: - 事件管理用的日历列表

    /// 可显示的日历（事件管理子页用）。
    func eventCalendars() -> [EKCalendar] {
        store.calendars(for: .event).sorted { ($0.title) < ($1.title) }
    }

    /// 可显示的提醒事项列表（事件管理子页用）。
    func reminderCalendars() -> [EKCalendar] {
        store.calendars(for: .reminder).sorted { ($0.title) < ($1.title) }
    }

    // MARK: - 读日程

    private func visibleEventCalendars() -> [EKCalendar]? {
        guard calendarAccess == .granted else { return nil }
        let hidden = hiddenCalendarIDs
        let calendars = eventCalendars().filter { !hidden.contains($0.calendarIdentifier) }
        return calendars.isEmpty ? nil : calendars
    }

    private func visibleReminderCalendars() -> [EKCalendar]? {
        guard remindersAccess == .granted else { return nil }
        let hidden = hiddenReminderListIDs
        let calendars = reminderCalendars().filter { !hidden.contains($0.calendarIdentifier) }
        return calendars.isEmpty ? nil : calendars
    }

    /// 读显示那个月的日程（只读没被隐藏的日历）。
    func loadEvents(for monthDate: Date) {
        guard calendarAccess == .granted else { return }
        let start = ChineseCalendarHelper.startOfMonth(for: monthDate)
        let end = ChineseCalendarHelper.addingDay(1, to: ChineseCalendarHelper.endOfMonth(for: monthDate))
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: visibleEventCalendars())
        let events = store.events(matching: predicate)
        var grouped: [Date: [EKEvent]] = [:]
        for event in events {
            guard let startDate = event.startDate else { continue }
            let day = ChineseCalendarHelper.gregorian.startOfDay(for: startDate)
            grouped[day, default: []].append(event)
        }
        for key in grouped.keys {
            grouped[key]?.sort { ($0.startDate ?? Date()) < ($1.startDate ?? Date()) }
        }
        eventsByDay = grouped
    }

    func events(on date: Date) -> [EKEvent] {
        let day = ChineseCalendarHelper.gregorian.startOfDay(for: date)
        return eventsByDay[day] ?? []
    }

    /// 某天事件小圆点的颜色（最多 3 个）。
    /// “使用系统事件颜色”开时取事件所属日历的颜色，否则用设置里的系统事件色。
    func eventDotColors(on date: Date, useSysColor: Bool, fallback: UIColor) -> [UIColor] {
        let events = events(on: date)
        var colors: [UIColor] = []
        for event in events.prefix(3) {
            if useSysColor, let cg = event.calendar.cgColor {
                colors.append(UIColor(cgColor: cg))
            } else {
                colors.append(fallback)
            }
        }
        return colors
    }

    /// 某天有没有到期的提醒（用来画提醒小点）。
    func hasReminders(on date: Date) -> Bool {
        reminderDays.contains(ChineseCalendarHelper.gregorian.startOfDay(for: date))
    }

    /// 读显示那个月各天有没有到期提醒（只读没被隐藏的列表）。
    func loadReminderDays(for monthDate: Date) {
        guard remindersAccess == .granted else {
            reminderDays = []
            return
        }
        let start = ChineseCalendarHelper.startOfMonth(for: monthDate)
        let end = ChineseCalendarHelper.addingDay(1, to: ChineseCalendarHelper.endOfMonth(for: monthDate))
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: start, ending: end, calendars: visibleReminderCalendars())
        let reminders: [EKReminder] = fetchRemindersSync(matching: predicate)
        var days: Set<Date> = []
        for reminder in reminders {
            if let due = reminder.dueDateComponents?.date {
                days.insert(ChineseCalendarHelper.gregorian.startOfDay(for: due))
            }
        }
        reminderDays = days
    }

    /// 读选中那天到期的未完成提醒。
    func loadReminders(for date: Date) async {
        guard remindersAccess == .granted else {
            remindersForDay = []
            return
        }
        let dayStart = ChineseCalendarHelper.gregorian.startOfDay(for: date)
        let dayEnd = ChineseCalendarHelper.addingDay(1, to: dayStart)
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: dayStart, ending: dayEnd, calendars: visibleReminderCalendars())
        // fetchReminders 的 async 形式要 iOS 18+ 的 SDK 才有，GitHub 这台机器的
        // SDK 里只有回调形式，这里用 continuation 包一层，老 SDK 也能编。
        let reminders: [EKReminder] = await withCheckedContinuation { continuation in
            _ = store.fetchReminders(matching: predicate) { found in
                continuation.resume(returning: found ?? [])
            }
        }
        remindersForDay = reminders.sorted {
            ($0.dueDateComponents?.date ?? Date()) < ($1.dueDateComponents?.date ?? Date())
        }
    }

    /// 同步取提醒（月视图画提醒小点用；回调里用信号量等一次结果）。
    private func fetchRemindersSync(matching predicate: NSPredicate) -> [EKReminder] {
        var result: [EKReminder] = []
        let semaphore = DispatchSemaphore(value: 0)
        _ = store.fetchReminders(matching: predicate) { found in
            result = found ?? []
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 5)
        return result
    }

    // MARK: - 写日程（添加 / 删除）

    /// 在默认日历上新建一个事件。
    func addEvent(title: String, start: Date, end: Date, allDay: Bool) throws {
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = end
        event.isAllDay = allDay
        event.calendar = store.defaultCalendarForNewEvents
        try store.save(event, span: .thisEvent)
    }

    /// 删除一个事件。
    func deleteEvent(_ event: EKEvent) throws {
        try store.remove(event, span: .thisEvent)
    }

    /// 时间段文字，如“09:00–10:30”，全天日程显示“全天”。
    static func timeText(for event: EKEvent) -> String {
        if event.isAllDay { return "全天" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        guard let start = event.startDate else { return "" }
        guard let end = event.endDate else { return formatter.string(from: start) }
        return "\(formatter.string(from: start))–\(formatter.string(from: end))"
    }
}
