import Foundation

/// 小组件用的农历 + 节假日换算（独立 target，放一份精简版）。
enum WidgetLunarHelper {

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

    // 法定休息日（与主 App 保持一致，2026-2027）
    private static let restDays: Set<String> = [
        "2026-01-01", "2026-01-02", "2026-01-03",
        "2026-02-15", "2026-02-16", "2026-02-17", "2026-02-18", "2026-02-19",
        "2026-02-20", "2026-02-21", "2026-02-22", "2026-02-23",
        "2026-04-04", "2026-04-05", "2026-04-06",
        "2026-05-01", "2026-05-02", "2026-05-03", "2026-05-04", "2026-05-05",
        "2026-06-19", "2026-06-20", "2026-06-21",
        "2026-09-25", "2026-09-26", "2026-09-27",
        "2026-10-01", "2026-10-02", "2026-10-03", "2026-10-04", "2026-10-05", "2026-10-06", "2026-10-07",
        "2027-01-01", "2027-01-02", "2027-01-03",
        "2027-02-05", "2027-02-06", "2027-02-07", "2027-02-08", "2027-02-09",
        "2027-02-10", "2027-02-11", "2027-02-12", "2027-02-13",
        "2027-04-03", "2027-04-04", "2027-04-05",
        "2027-05-01", "2027-05-02", "2027-05-03", "2027-05-04", "2027-05-05",
        "2027-06-09",
        "2027-09-15",
        "2027-10-01", "2027-10-02", "2027-10-03", "2027-10-04", "2027-10-05", "2027-10-06", "2027-10-07"
    ]

    private static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func isRestDay(_ date: Date) -> Bool {
        restDays.contains(dateKeyFormatter.string(from: date))
    }

    static func weekdayShortName(for date: Date) -> String {
        let names = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return names[gregorian.component(.weekday, from: date) - 1]
    }
}
