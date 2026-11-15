import EventKit
import Foundation

/// 读系统日历和提醒事项（EventKit）。
/// 只读，不写，不建、不改、不删用户的任何日程和提醒。
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

    /// 读显示那个月的日程。
    func loadEvents(for monthDate: Date) {
        guard calendarAccess == .granted else { return }
        let start = ChineseCalendarHelper.startOfMonth(for: monthDate)
        let end = ChineseCalendarHelper.addingDay(1, to: ChineseCalendarHelper.endOfMonth(for: monthDate))
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
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

    /// 读选中那天到期的未完成提醒。
    func loadReminders(for date: Date) async {
        guard remindersAccess == .granted else {
            remindersForDay = []
            return
        }
        let dayStart = ChineseCalendarHelper.gregorian.startOfDay(for: date)
        let dayEnd = ChineseCalendarHelper.addingDay(1, to: dayStart)
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: dayStart, ending: dayEnd, calendars: nil)
        do {
            let reminders = try await store.fetchReminders(matching: predicate)
            remindersForDay = reminders.sorted {
                ($0.dueDateComponents?.date ?? Date()) < ($1.dueDateComponents?.date ?? Date())
            }
        } catch {
            remindersForDay = []
        }
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
