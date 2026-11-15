import Foundation

/// 中国日历换算：公历 + 农历（中国农历）。
/// 农历用 Foundation 自带的中国农历（Calendar.Identifier.chinese），
/// 不用自己算闰月和天干地支的历法表。
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

    /// 农历月名，闰月前面加“闰”，如“闰六月”。
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

    /// 月视图格子里的小字：初一显示月份（如“九月”“冬月”），其余显示日子（如“廿三”）。
    static func lunarShortString(for date: Date) -> String {
        let c = lunarComponents(for: date)
        if c.day == 1 { return lunarMonthName(for: date) }
        return lunarDayName(for: date)
    }

    /// 完整农历日期，如“九月廿三”“闰六月十五”。
    static func lunarDateString(for date: Date) -> String {
        lunarMonthName(for: date) + lunarDayName(for: date)
    }

    /// 天干地支年，如“乙巳年”。农历年按春节换年，这里用公历年近似，
    /// 春节前那几天会按公历年算，详情页会另外标注农历年。
    static func stemBranchYear(for date: Date) -> String {
        let year = gregorian.component(.year, from: date)
        let stem = stems[(year - 4) % 10]
        let branch = branches[(year - 4) % 12]
        return "\(stem)\(branch)年"
    }

    /// 生肖，如“蛇”。
    static func zodiac(for date: Date) -> String {
        let year = gregorian.component(.year, from: date)
        return zodiacs[(year - 4) % 12]
    }

    /// 完整农历，如“乙巳年 · 九月廿三 · 蛇年”。
    static func lunarFullString(for date: Date) -> String {
        "\(stemBranchYear(for: date)) · \(lunarDateString(for: date)) · \(zodiac(for: date))年"
    }

    // MARK: - 节日

    /// 农历节日（按农历月日）+ 几个公历节日。
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
            // 除夕：农历腊月最后一天。
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

    // MARK: - 法定节假日（2026 年）

    /// 法定节假日安排。数据来源：国务院办公厅《关于 2026 年部分节假日安排的通知》
    /// （国办发明电〔2025〕7 号，2025 年 11 月 4 日）。
    /// 2027 年及以后的安排还没写进来，到了那年要更新这张表。
    enum StatutoryDay {
        case holiday(name: String)  // 放假
        case workday                // 调休上班
    }

    /// （节日名，开始月，开始日，结束月，结束日）
    private static let statutoryHolidays2026: [(String, Int, Int, Int, Int)] = [
        ("元旦", 1, 1, 1, 3),
        ("春节", 2, 15, 2, 23),
        ("清明节", 4, 4, 4, 6),
        ("劳动节", 5, 1, 5, 5),
        ("端午节", 6, 19, 6, 21),
        ("中秋节", 9, 25, 9, 27),
        ("国庆节", 10, 1, 10, 7),
    ]

    /// 调休上班日（月，日）
    private static let statutoryWorkdays2026: [(Int, Int)] = [
        (1, 4), (2, 14), (2, 28), (5, 9), (9, 20), (10, 10),
    ]

    /// 某天是不是 2026 年的放假日或调休上班日。其他年份返回 nil。
    static func statutoryDay(for date: Date) -> StatutoryDay? {
        let comps = gregorian.dateComponents([.year, .month, .day], from: date)
        guard comps.year == 2026, let month = comps.month, let day = comps.day else { return nil }
        for (name, sm, sd, em, ed) in statutoryHolidays2026 {
            let afterStart = (month > sm) || (month == sm && day >= sd)
            let beforeEnd = (month < em) || (month == em && day <= ed)
            if afterStart && beforeEnd { return .holiday(name: name) }
        }
        if statutoryWorkdays2026.contains(where: { $0 == month && $1 == day }) {
            return .workday
        }
        return nil
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
        let w = gregorian.component(.weekday, from: date) // 1 = 周日
        return names[w - 1]
    }

    /// 一年中的第几周（1 月 1 日所在周为第 1 周）。
    static func weekOfYear(for date: Date) -> Int {
        gregorian.component(.weekOfYear, from: date)
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

    /// 某个月的日历格子：从周日开始的整周，含上月、下月补齐的天。
    static func monthGridDays(for monthDate: Date) -> [Date] {
        let comps = gregorian.dateComponents([.year, .month], from: monthDate)
        guard let first = gregorian.date(from: comps) else { return [] }
        let firstWeekday = gregorian.component(.weekday, from: first) // 1 = 周日
        let leading = firstWeekday - 1
        guard let start = gregorian.date(byAdding: .day, value: -leading, to: first),
              let daysInMonth = gregorian.range(of: .day, in: .month, for: first)?.count else { return [] }
        let total = ((leading + daysInMonth + 6) / 7) * 7
        return (0..<total).compactMap { gregorian.date(byAdding: .day, value: $0, to: start) }
    }

    /// 把月历格子按周切开，每周 7 天。
    static func monthWeeks(for monthDate: Date) -> [[Date]] {
        let days = monthGridDays(for: monthDate)
        return stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
    }

    /// 某天所在的那一周（周日到周六，7 天）。
    static func weekContaining(_ date: Date) -> [Date] {
        let weekday = gregorian.component(.weekday, from: date) // 1 = 周日
        guard let start = gregorian.date(byAdding: .day, value: -(weekday - 1), to: gregorian.startOfDay(for: date)) else { return [] }
        return (0..<7).compactMap { gregorian.date(byAdding: .day, value: $0, to: start) }
    }

    static func month(of date: Date) -> Int {
        gregorian.component(.month, from: date)
    }

    static func addingMonth(_ value: Int, to date: Date) -> Date {
        gregorian.date(byAdding: .month, value: value, to: date) ?? date
    }

    static func addingDay(_ value: Int, to date: Date) -> Date {
        gregorian.date(byAdding: .day, value: value, to: date) ?? date
    }

    static func startOfMonth(for date: Date) -> Date {
        let comps = gregorian.dateComponents([.year, .month], from: date)
        return gregorian.date(from: comps) ?? date
    }

    static func endOfMonth(for date: Date) -> Date {
        guard let start = gregorian.date(from: gregorian.dateComponents([.year, .month], from: date)),
              let days = gregorian.range(of: .day, in: .month, for: start)?.count else { return date }
        return gregorian.date(byAdding: .day, value: days - 1, to: start) ?? date
    }
}
