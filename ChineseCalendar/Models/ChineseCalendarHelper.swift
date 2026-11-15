import Foundation

/// 中国日历换算：公历 + 农历 + 法定节假日/调休 + 二十四节气。
enum ChineseCalendarHelper {

    static let gregorian: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "zh_CN")
        c.timeZone = TimeZone.current
        return c
    }()

    static let chinese: Calendar = {
        var c = Calendar(identifier: .chinese)
        c.locale = Locale(identifier: "zh_CN")
        c.timeZone = TimeZone.current
        return c
    }()

    // MARK: - 农历名称

    private static let lunarMonths = ["正月", "二月", "三月", "四月", "五月", "六月",
                                       "七月", "八月", "九月", "十月", "冬月", "腊月"]
    private static let lunarDays = ["初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
                                    "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
                                    "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"]
    private static let stems = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
    private static let branches = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
    private static let zodiacs = ["鼠", "牛", "虎", "兔", "龙", "蛇", "马", "羊", "猴", "鸡", "狗", "猪"]

    static func lunarComponents(for date: Date) -> DateComponents {
        chinese.dateComponents([.year, .month, .day, .isLeapMonth], from: date)
    }

    static func lunarMonthName(for date: Date) -> String {
        let c = lunarComponents(for: date)
        guard let month = c.month, month >= 1, month <= 12 else { return "" }
        let name = lunarMonths[month - 1]
        return (c.isLeapMonth == true) ? "闰\(name)" : name
    }

    static func lunarDayName(for date: Date) -> String {
        let c = lunarComponents(for: date)
        guard let day = c.day, day >= 1, day <= 30 else { return "" }
        return lunarDays[day - 1]
    }

    static func lunarShortString(for date: Date) -> String {
        let c = lunarComponents(for: date)
        if c.day == 1 { return lunarMonthName(for: date) }
        return lunarDayName(for: date)
    }

    static func lunarDateString(for date: Date) -> String {
        lunarMonthName(for: date) + lunarDayName(for: date)
    }

    static func stemBranchYear(for date: Date) -> String {
        let year = gregorian.component(.year, from: date)
        return "\(stems[(year - 4) % 10])\(branches[(year - 4) % 12])年"
    }

    static func zodiac(for date: Date) -> String {
        let year = gregorian.component(.year, from: date)
        return zodiacs[(year - 4) % 12]
    }

    static func lunarFullString(for date: Date) -> String {
        "\(stemBranchYear(for: date)) · \(lunarDateString(for: date)) · \(zodiac(for: date))年"
    }

    // MARK: - 传统节日 / 公历节日

    static func festival(for date: Date) -> String? {
        let lunar = lunarComponents(for: date)
        if let month = lunar.month, let day = lunar.day {
            switch (month, day) {
            case (1, 1): return "春节"
            case (1, 15): return "元宵节"
            case (2, 2): return "龙抬头"
            case (5, 5): return "端午节"
            case (7, 7): return "七夕节"
            case (7, 15): return "中元节"
            case (8, 15): return "中秋节"
            case (9, 9): return "重阳节"
            case (12, 8): return "腊八节"
            default: break
            }
            if month == 12, let days = chinese.range(of: .day, in: .month, for: date)?.count, day == days {
                return "除夕"
            }
        }
        let g = gregorian.dateComponents([.month, .day], from: date)
        switch (g.month, g.day) {
        case (1, 1): return "元旦"
        case (5, 1): return "劳动节"
        case (10, 1): return "国庆节"
        default: return nil
        }
    }

    // MARK: - 法定节假日 & 调休（国务院官方安排）

    /// 休息日（放假）
    private static let restDays: Set<String> = [
        // 2026
        "2026-01-01", "2026-01-02", "2026-01-03",
        "2026-02-15", "2026-02-16", "2026-02-17", "2026-02-18", "2026-02-19",
        "2026-02-20", "2026-02-21", "2026-02-22", "2026-02-23",
        "2026-04-04", "2026-04-05", "2026-04-06",
        "2026-05-01", "2026-05-02", "2026-05-03", "2026-05-04", "2026-05-05",
        "2026-06-19", "2026-06-20", "2026-06-21",
        "2026-09-25", "2026-09-26", "2026-09-27",
        "2026-10-01", "2026-10-02", "2026-10-03", "2026-10-04", "2026-10-05", "2026-10-06", "2026-10-07",
        // 2027
        "2027-01-01", "2027-01-02", "2027-01-03",
        "2027-02-05", "2027-02-06", "2027-02-07", "2027-02-08", "2027-02-09",
        "2027-02-10", "2027-02-11", "2027-02-12", "2027-02-13",
        "2027-04-03", "2027-04-04", "2027-04-05",
        "2027-05-01", "2027-05-02", "2027-05-03", "2027-05-04", "2027-05-05",
        "2027-06-09",
        "2027-09-15",
        "2027-10-01", "2027-10-02", "2027-10-03", "2027-10-04", "2027-10-05", "2027-10-06", "2027-10-07"
    ]

    /// 调休上班日（原本是周末但要上班）
    private static let workDays: Set<String> = [
        // 2026
        "2026-01-04",
        "2026-02-14", "2026-02-28",
        "2026-05-09",
        "2026-09-20", "2026-10-10",
        // 2027
        "2027-01-31", "2027-02-14",
        "2027-05-08",
        "2027-09-26", "2027-10-09"
    ]

    private static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func key(for date: Date) -> String {
        dateKeyFormatter.string(from: date)
    }

    /// 是否法定休息日（含调休放假）
    static func isRestDay(_ date: Date) -> Bool {
        restDays.contains(key(for: date))
    }

    /// 是否调休上班日
    static func isExtraWorkDay(_ date: Date) -> Bool {
        workDays.contains(key(for: date))
    }

    /// 当天状态：休 / 班 / nil（普通工作日或周末）
    static func workStatus(for date: Date) -> String? {
        if isRestDay(date) { return "休" }
        if isExtraWorkDay(date) { return "班" }
        return nil
    }

    /// 是否工作日（考虑调休）
    static func isWorkday(_ date: Date) -> Bool {
        if isRestDay(date) { return false }
        if isExtraWorkDay(date) { return true }
        let weekday = gregorian.component(.weekday, from: date)
        return weekday != 1 && weekday != 7   // 不是周日和周六
    }

    // MARK: - 二十四节气（近似日期，误差一般不超过 1 天）

    private static let solarTerms: [(month: Int, day: Int, name: String)] = [
        (2, 4, "立春"), (2, 19, "雨水"),
        (3, 6, "惊蛰"), (3, 21, "春分"),
        (4, 5, "清明"), (4, 20, "谷雨"),
        (5, 6, "立夏"), (5, 21, "小满"),
        (6, 6, "芒种"), (6, 21, "夏至"),
        (7, 7, "小暑"), (7, 23, "大暑"),
        (8, 8, "立秋"), (8, 23, "处暑"),
        (9, 8, "白露"), (9, 23, "秋分"),
        (10, 8, "寒露"), (10, 23, "霜降"),
        (11, 7, "立冬"), (11, 22, "小雪"),
        (12, 7, "大雪"), (12, 22, "冬至"),
        (1, 6, "小寒"), (1, 20, "大寒")
    ]

    static func solarTerm(for date: Date) -> String? {
        let m = gregorian.component(.month, from: date)
        let d = gregorian.component(.day, from: date)
        return solarTerms.first { $0.month == m && $0.day == d }?.name
    }

    // MARK: - 日期工具

    static func isSameDay(_ a: Date, _ b: Date) -> Bool {
        gregorian.isDate(a, inSameDayAs: b)
    }

    static func isToday(_ date: Date) -> Bool {
        gregorian.isDateInToday(date)
    }

    static func weekdayName(for date: Date) -> String {
        let names = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return names[gregorian.component(.weekday, from: date) - 1]
    }

    static func monthTitle(for date: Date) -> String {
        let y = gregorian.component(.year, from: date)
        let m = gregorian.component(.month, from: date)
        return "\(y)年\(m)月"
    }

    static func fullGregorianString(for date: Date) -> String {
        let y = gregorian.component(.year, from: date)
        let m = gregorian.component(.month, from: date)
        let d = gregorian.component(.day, from: date)
        return "\(y)年\(m)月\(d)日 \(weekdayName(for: date))"
    }

    /// 月历格子。weekStartsOnMonday 控制周起始日。
    static func monthGridDays(for monthDate: Date, weekStartsOnMonday: Bool = false) -> [Date] {
        let comps = gregorian.dateComponents([.year, .month], from: monthDate)
        guard let first = gregorian.date(from: comps) else { return [] }
        let firstWeekday = gregorian.component(.weekday, from: first) // 1 = 周日
        let leading: Int
        if weekStartsOnMonday {
            // 周一 = 0, 周日 = 6
            leading = (firstWeekday + 5) % 7
        } else {
            leading = firstWeekday - 1
        }
        guard let start = gregorian.date(byAdding: .day, value: -leading, to: first),
              let daysInMonth = gregorian.range(of: .day, in: .month, for: first)?.count else { return [] }
        let total = ((leading + daysInMonth + 6) / 7) * 7
        return (0..<total).compactMap { gregorian.date(byAdding: .day, value: $0, to: start) }
    }

    static func month(of date: Date) -> Int {
        gregorian.component(.month, from: date)
    }

    static func addingMonth(_ value: Int, to date: Date) -> Date {
        gregorian.date(byAdding: .month, value: value, to: date) ?? date
    }
}
