import Foundation

/// 小组件用的农历 + 节气 + 节日 + 休/班换算（独立 target，放一份精简版，
/// 与主 App 的 ChineseCalendarHelper 同一套数据：节日表、节气表、休/班表）。
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

    /// 农历年（按春节换年，春节前算上一年）。
    /// 注意：Foundation 中国农历的 year 分量是黄帝纪元（2026 年对应 4663），
    /// 不能直接当公历年用——2026 年会算成癸卯年。干支/生肖按公历年 + 春节分界推导：
    /// 公历 1–2 月且农历还没到正月（腊月或冬月），还在上一个农历年。
    static func lunarYear(for date: Date) -> Int {
        let gYear = gregorian.component(.year, from: date)
        let gMonth = gregorian.component(.month, from: date)
        let lunarMonth = lunarComponents(for: date).month ?? 1
        if gMonth <= 2 && lunarMonth != 1 {
            return gYear - 1
        }
        return gYear
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
        let year = lunarYear(for: date)
        return "\(stems[(year - 4) % 10])\(branches[(year - 4) % 12])年"
    }

    static func zodiac(for date: Date) -> String {
        zodiacs[(lunarYear(for: date) - 4) % 12]
    }

    // MARK: - 日模型

    struct DayInfo {
        let date: Date
        let lunarDay: Int
        let lunarMonthName: String
        let lunarFestival: String?
        let solarFestival: String?
        let weekFestival: String?
        let term: String?
        let worktime: Int
        let week: Int
        let isWeekend: Bool

        var hasHoliday: Bool {
            if lunarFestival != nil { return true }
            if term != nil { return true }
            if let s = solarFestival, !s.hasPrefix("*") { return true }
            if let w = weekFestival, !w.hasPrefix("*") { return true }
            return lunarDay == 1
        }

        var displayName: String? {
            if let f = lunarFestival { return f }
            if let t = term { return t }
            if let s = solarFestival, !s.hasPrefix("*") { return s }
            if let w = weekFestival, !w.hasPrefix("*") { return w }
            if lunarDay == 1 { return lunarMonthName }
            return nil
        }
    }

    static func dayInfo(for date: Date) -> DayInfo {
        let lunar = lunarComponents(for: date)
        let weekday = gregorian.component(.weekday, from: date)
        return DayInfo(
            date: date,
            lunarDay: lunar.day ?? 1,
            lunarMonthName: lunarMonthName(for: date),
            lunarFestival: lunarFestival(for: date),
            solarFestival: solarFestival(for: date),
            weekFestival: weekFestival(for: date),
            term: solarTerm(for: date),
            worktime: worktime(for: date),
            week: weekOfYear(for: date),
            isWeekend: weekday == 1 || weekday == 7
        )
    }

    // MARK: - 节日

    private static let lunarFestivals: [String: String] = [
        "1-1": "春节", "1-15": "元宵节", "2-2": "龙抬头节",
        "5-5": "端午节", "7-7": "七夕节", "7-15": "中元节",
        "8-15": "中秋节", "9-9": "重阳节", "10-1": "寒衣节",
        "10-15": "下元节", "12-8": "腊八节",
    ]

    static func lunarFestival(for date: Date) -> String? {
        let lunar = lunarComponents(for: date)
        guard let month = lunar.month, let day = lunar.day else { return nil }
        if let name = lunarFestivals["\(month)-\(day)"] { return name }
        if month == 12, let days = chinese.range(of: .day, in: .month, for: date)?.count, day == days {
            return "除夕"
        }
        return nil
    }

    private static let solarFestivals: [String: String] = [
        "1-1": "元旦节", "2-2": "世界湿地日", "2-14": "情人节",
        "3-5": "学雷锋纪念日", "3-8": "妇女节", "3-12": "植树节 孙中山逝世纪念日",
        "3-15": "消费者权益日", "3-21": "世界森林日 消除种族歧视国际日 世界儿歌日",
        "4-1": "愚人节 全国爱国卫生运动月 税收宣传月", "5-1": "劳动节", "5-4": "青年节",
        "5-12": "国际护士节", "5-18": "国际博物馆日", "6-1": "国际儿童节",
        "6-5": "世界环境日", "6-23": "国际奥林匹克日",
        "7-1": "建党节 香港回归纪念日 中共诞辰 世界建筑日", "8-1": "建军节",
        "9-3": "抗日战争胜利纪念日", "9-10": "中国教师节", "9-28": "*孔子诞辰",
        "10-1": "国庆节 世界音乐日 国际老人节", "10-31": "万圣夜 世界勤俭日",
        "11-11": "光棍节", "12-1": "*世界艾滋病日", "12-10": "*世界人权日",
        "12-13": "*南京大屠杀(1937年)纪念日！谨记血泪史！", "12-20": "*澳门回归纪念",
        "12-25": "圣诞节", "12-26": "*毛泽东诞辰纪念",
    ]

    static func solarFestival(for date: Date) -> String? {
        let g = gregorian.dateComponents([.month, .day], from: date)
        guard let month = g.month, let day = g.day else { return nil }
        if month == 5, nthWeekdayInMonth(date, weekday: 1, nth: 2) != nil { return "国际母亲节 救助贫困母亲日" }
        if month == 6, nthWeekdayInMonth(date, weekday: 1, nth: 3) != nil { return "父亲节" }
        if month == 11, nthWeekdayInMonth(date, weekday: 5, nth: 4) != nil { return "感恩节" }
        return solarFestivals["\(month)-\(day)"]
    }

    private static func nthWeekdayInMonth(_ date: Date, weekday: Int, nth: Int) -> Date? {
        let comps = gregorian.dateComponents([.year, .month, .day, .weekday], from: date)
        guard let year = comps.year, let month = comps.month, let day = comps.day,
              comps.weekday == weekday else { return nil }
        guard let first = gregorian.date(from: DateComponents(year: year, month: month, day: 1)) else { return nil }
        let firstWeekday = gregorian.component(.weekday, from: first)
        let firstDate = 1 + ((weekday - firstWeekday + 7) % 7)
        return day == firstDate + (nth - 1) * 7 ? date : nil
    }

    static func weekFestival(for date: Date) -> String? {
        let year = gregorian.component(.year, from: date)
        guard let nov11 = gregorian.date(from: DateComponents(year: year, month: 11, day: 11)) else { return nil }
        let week = weekContaining(nov11)
        return week.contains(where: { gregorian.isDate($0, inSameDayAs: date) }) ? "*国际科学与和平周(本日所属的一周)" : nil
    }

    // MARK: - 24 节气

    private static let solarTerms: [Int: [(Int, Int, String)]] = [
        2025: [(2, 3, "立春"), (2, 18, "雨水"), (3, 5, "惊蛰"), (3, 20, "春分"), (4, 4, "清明"), (4, 20, "谷雨"),
               (5, 5, "立夏"), (5, 21, "小满"), (6, 5, "芒种"), (6, 21, "夏至"), (7, 7, "小暑"), (7, 22, "大暑"),
               (8, 7, "立秋"), (8, 23, "处暑"), (9, 7, "白露"), (9, 23, "秋分"), (10, 8, "寒露"), (10, 23, "霜降"),
               (11, 7, "立冬"), (11, 22, "小雪"), (12, 7, "大雪"), (12, 21, "冬至")],
        2026: [(2, 4, "立春"), (2, 18, "雨水"), (3, 5, "惊蛰"), (3, 20, "春分"), (4, 4, "清明"), (4, 20, "谷雨"),
               (5, 5, "立夏"), (5, 21, "小满"), (6, 5, "芒种"), (6, 21, "夏至"), (7, 7, "小暑"), (7, 22, "大暑"),
               (8, 7, "立秋"), (8, 23, "处暑"), (9, 7, "白露"), (9, 22, "秋分"), (10, 8, "寒露"), (10, 23, "霜降"),
               (11, 7, "立冬"), (11, 22, "小雪"), (12, 7, "大雪"), (12, 21, "冬至")],
        2027: [(2, 4, "立春"), (2, 18, "雨水"), (3, 5, "惊蛰"), (3, 20, "春分"), (4, 5, "清明"), (4, 20, "谷雨"),
               (5, 5, "立夏"), (5, 21, "小满"), (6, 6, "芒种"), (6, 21, "夏至"), (7, 7, "小暑"), (7, 23, "大暑"),
               (8, 7, "立秋"), (8, 23, "处暑"), (9, 7, "白露"), (9, 23, "秋分"), (10, 8, "寒露"), (10, 23, "霜降"),
               (11, 7, "立冬"), (11, 22, "小雪"), (12, 7, "大雪"), (12, 22, "冬至")],
    ]

    static func solarTerm(for date: Date) -> String? {
        let comps = gregorian.dateComponents([.year, .month, .day], from: date)
        guard let year = comps.year, let month = comps.month, let day = comps.day,
              let terms = solarTerms[year] else { return nil }
        return terms.first(where: { $0.0 == month && $0.1 == day })?.2
    }

    // MARK: - 休/班（2025–2027，国办发明电）

    private static let statutoryHolidays: [Int: [(String, Int, Int, Int, Int)]] = [
        2025: [("元旦", 1, 1, 1, 1), ("春节", 1, 28, 2, 4), ("清明节", 4, 4, 4, 6),
               ("劳动节", 5, 1, 5, 5), ("端午节", 5, 31, 6, 2), ("中秋节", 10, 1, 10, 8),
               ("国庆节", 10, 1, 10, 8)],
        2026: [("元旦", 1, 1, 1, 3), ("春节", 2, 15, 2, 23), ("清明节", 4, 4, 4, 6),
               ("劳动节", 5, 1, 5, 5), ("端午节", 6, 19, 6, 21), ("中秋节", 9, 25, 9, 27),
               ("国庆节", 10, 1, 10, 7)],
        2027: [("元旦", 1, 1, 1, 3), ("春节", 2, 5, 2, 13), ("清明节", 4, 3, 4, 5),
               ("劳动节", 5, 1, 5, 5), ("端午节", 6, 9, 6, 9), ("中秋节", 9, 15, 9, 15),
               ("国庆节", 10, 1, 10, 7)],
    ]

    private static let statutoryWorkdays: [Int: [(Int, Int)]] = [
        2025: [(1, 26), (2, 8), (4, 27), (9, 28), (10, 11)],
        2026: [(1, 4), (2, 14), (2, 28), (5, 9), (9, 20), (10, 10)],
        2027: [(1, 31), (2, 14), (5, 8), (9, 26), (10, 9)],
    ]

    static func worktime(for date: Date) -> Int {
        let comps = gregorian.dateComponents([.year, .month, .day], from: date)
        guard let year = comps.year, let month = comps.month, let day = comps.day,
              let holidays = statutoryHolidays[year] else { return 0 }
        for (_, sm, sd, em, ed) in holidays {
            let afterStart = (month > sm) || (month == sm && day >= sd)
            let beforeEnd = (month < em) || (month == em && day <= ed)
            if afterStart && beforeEnd { return 2 }
        }
        if let workdays = statutoryWorkdays[year],
           workdays.contains(where: { $0 == month && $1 == day }) {
            return 1
        }
        return 0
    }

    static func isRestDay(_ date: Date) -> Bool {
        worktime(for: date) == 2
    }

    // MARK: - 日期工具

    static func weekOfYear(for date: Date) -> Int {
        gregorian.component(.weekOfYear, from: date)
    }

    static func weekdayShortName(for date: Date) -> String {
        let names = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return names[gregorian.component(.weekday, from: date) - 1]
    }

    static func weekdaySymbols() -> [String] {
        let names = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let start = AppSettings.readWeekStartDay()
        return (0..<7).map { names[(start + $0) % 7] }
    }

    static func weekContaining(_ date: Date) -> [Date] {
        let weekday = gregorian.component(.weekday, from: date)
        let start = AppSettings.readWeekStartDay() + 1
        let offset = (weekday - start + 7) % 7
        guard let weekStart = gregorian.date(byAdding: .day, value: -offset, to: gregorian.startOfDay(for: date)) else { return [] }
        return (0..<7).compactMap { gregorian.date(byAdding: .day, value: $0, to: weekStart) }
    }

    static func festival(for date: Date) -> String? {
        dayInfo(for: date).displayName
    }
}
