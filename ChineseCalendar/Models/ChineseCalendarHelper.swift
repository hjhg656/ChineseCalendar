import Foundation

/// 中国日历换算：公历 + 农历（中国农历）+ 节气 + 节日 + 休/班。
/// 农历用 Foundation 自带的中国农历（Calendar.Identifier.chinese），
/// 不用自己算闰月和天干地支的历法表。
/// 节日名、节气、休/班按小历的规格内置（见 README）：
/// - 公历/农历节日与 `*` 次要节日（`*` 开头的不算节日，月视图不显示，只进日详情）
/// - 24 节气按年内置 2025–2027 年日期表
/// - 休/班表按国务院办公厅放假通知内置 2025–2027 年（1 = 调休上班，2 = 放假）
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

    /// 天干地支年，如“丙午年”（按农历年算，春节前算上一年）。
    static func stemBranchYear(for date: Date) -> String {
        let year = lunarYear(for: date)
        return "\(stems[(year - 4) % 10])\(branches[(year - 4) % 12])年"
    }

    /// 生肖，如“马”（按农历年算）。
    static func zodiac(for date: Date) -> String {
        zodiacs[(lunarYear(for: date) - 4) % 12]
    }

    /// 完整农历，如“丙午(马)年 十月初十”。
    static func lunarFullString(for date: Date) -> String {
        "\(stemBranchYear(for: date).dropLast())(\(zodiac(for: date)))年 \(lunarDateString(for: date))"
    }

    // MARK: - 日模型

    struct DayInfo {
        let date: Date
        let lunarDay: Int
        let lunarMonthName: String
        let lunarDayName: String
        let lunarFestival: String?
        let solarFestival: String?
        let weekFestival: String?
        let term: String?
        let worktime: Int          // 0 普通，1 调休上班，2 放假
        let ganZhiYear: String
        let zodiac: String
        let week: Int
        let isWeekend: Bool

        /// 是否算节日（月视图显示节日名、副行着节日色）。
        /// 规则（小历）：农历节日、节气、非 `*` 公历节日、非 `*` 周节日、初一。
        var hasHoliday: Bool {
            if lunarFestival != nil { return true }
            if term != nil { return true }
            if let s = solarFestival, !s.hasPrefix("*") { return true }
            if let w = weekFestival, !w.hasPrefix("*") { return true }
            return lunarDay == 1
        }

        /// 月视图格子副行要显示的名字（节日名优先，否则初一显示月名）。
        var displayName: String? {
            if let f = lunarFestival { return f }
            if let t = term { return t }
            if let s = solarFestival, !s.hasPrefix("*") { return s }
            if let w = weekFestival, !w.hasPrefix("*") { return w }
            if lunarDay == 1 { return lunarMonthName }
            return nil
        }

        /// 日详情事件列表里的节日名（含 `*` 次要节日，去掉 `*` 后显示）。
        var detailNames: [String] {
            var names: [String] = []
            if let f = lunarFestival { names.append(f) }
            if let t = term { names.append(t) }
            if let s = solarFestival { names.append(s.hasPrefix("*") ? String(s.dropFirst()) : s) }
            if let w = weekFestival { names.append(w.hasPrefix("*") ? String(w.dropFirst()) : w) }
            return names
        }
    }

    static func dayInfo(for date: Date) -> DayInfo {
        let lunar = lunarComponents(for: date)
        let g = gregorian.dateComponents([.month, .day, .weekday], from: date)
        let month = g.month ?? 1
        let day = g.day ?? 1
        let weekday = g.weekday ?? 1
        return DayInfo(
            date: date,
            lunarDay: lunar.day ?? 1,
            lunarMonthName: lunarMonthName(for: date),
            lunarDayName: lunarDayName(for: date),
            lunarFestival: lunarFestival(for: date),
            solarFestival: solarFestival(for: date),
            weekFestival: weekFestival(for: date),
            term: solarTerm(for: date),
            worktime: worktime(for: date),
            ganZhiYear: stemBranchYear(for: date),
            zodiac: zodiac(for: date),
            week: weekOfYear(for: date),
            isWeekend: weekday == 1 || weekday == 7
        )
    }

    // MARK: - 农历节日

    /// 农历节日（键：农历月-日）。除夕单独算（腊月最后一天）。
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
        // 除夕：农历腊月最后一天。
        if month == 12, let days = chinese.range(of: .day, in: .month, for: date)?.count, day == days {
            return "除夕"
        }
        return nil
    }

    // MARK: - 公历节日

    /// 公历节日（键：公历月-日）。`*` 开头的是次要节日/纪念日：
    /// 月视图不显示、不着节日色，只在日详情里出现。
    private static let solarFestivals: [String: String] = [
        "1-1": "元旦节",
        "2-2": "世界湿地日",
        "2-14": "情人节",
        "3-5": "学雷锋纪念日",
        "3-8": "妇女节",
        "3-12": "植树节 孙中山逝世纪念日",
        "3-15": "消费者权益日",
        "3-21": "世界森林日 消除种族歧视国际日 世界儿歌日",
        "4-1": "愚人节 全国爱国卫生运动月 税收宣传月",
        "5-1": "劳动节",
        "5-4": "青年节",
        "5-12": "国际护士节",
        "5-18": "国际博物馆日",
        "6-1": "国际儿童节",
        "6-5": "世界环境日",
        "6-23": "国际奥林匹克日",
        "7-1": "建党节 香港回归纪念日 中共诞辰 世界建筑日",
        "8-1": "建军节",
        "9-3": "抗日战争胜利纪念日",
        "9-10": "中国教师节",
        "9-28": "*孔子诞辰",
        "10-1": "国庆节 世界音乐日 国际老人节",
        "10-31": "万圣夜 世界勤俭日",
        "11-11": "光棍节",
        "12-1": "*世界艾滋病日",
        "12-10": "*世界人权日",
        "12-13": "*南京大屠杀(1937年)纪念日！谨记血泪史！",
        "12-20": "*澳门回归纪念",
        "12-25": "圣诞节",
        "12-26": "*毛泽东诞辰纪念",
    ]

    static func solarFestival(for date: Date) -> String? {
        let g = gregorian.dateComponents([.month, .day], from: date)
        guard let month = g.month, let day = g.day else { return nil }
        // 母亲节：5 月第 2 个周日；父亲节：6 月第 3 个周日。
        if month == 5, let nth = nthWeekdayInMonth(date, weekday: 1, nth: 2) { return "国际母亲节 救助贫困母亲日" }
        if month == 6, let _ = nthWeekdayInMonth(date, weekday: 1, nth: 3) { return "父亲节" }
        // 感恩节：11 月第 4 个周四。
        if month == 11, let _ = nthWeekdayInMonth(date, weekday: 5, nth: 4) { return "感恩节" }
        return solarFestivals["\(month)-\(day)"]
    }

    /// 判断某天是不是当月第 n 个星期几（weekday：1 周日 … 7 周六）。
    private static func nthWeekdayInMonth(_ date: Date, weekday: Int, nth: Int) -> Date? {
        let comps = gregorian.dateComponents([.year, .month, .day, .weekday], from: date)
        guard let year = comps.year, let month = comps.month, let day = comps.day,
              comps.weekday == weekday else { return nil }
        // 当月第 1 个该星期几是几号。
        guard let first = gregorian.date(from: DateComponents(year: year, month: month, day: 1)) else { return nil }
        let firstWeekday = gregorian.component(.weekday, from: first)
        let firstDate = 1 + ((weekday - firstWeekday + 7) % 7)
        return day == firstDate + (nth - 1) * 7 ? date : nil
    }

    // MARK: - 周节日

    /// 周节日：11 月 11 日所在的那一周是国际科学与和平周。
    static func weekFestival(for date: Date) -> String? {
        let year = gregorian.component(.year, from: date)
        guard let nov11 = gregorian.date(from: DateComponents(year: year, month: 11, day: 11)) else { return nil }
        let week = weekContaining(nov11)
        return week.contains(where: { isSameDay($0, date) }) ? "*国际科学与和平周(本日所属的一周)" : nil
    }

    // MARK: - 24 节气（按年内置日期表）

    /// （月，日，名）。2026 年立冬 11-7 / 小雪 11-22 与用户真机截图一致。
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

    // MARK: - 法定节假日与休/班

    /// 放假或调休上班。数据来源：国务院办公厅放假通知。
    /// 2025 年：国办发明电〔2024〕12 号；2026 年：国办发明电〔2025〕7 号；
    /// 2027 年：国办发明电〔2026〕10 号（2026-11-05 发布，已对照原文核对）。
    enum StatutoryDay {
        case holiday(name: String)  // 放假
        case workday                // 调休上班
    }

    /// （节日名，开始月，开始日，结束月，结束日）
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

    /// 调休上班日（月，日）
    private static let statutoryWorkdays: [Int: [(Int, Int)]] = [
        2025: [(1, 26), (2, 8), (4, 27), (9, 28), (10, 11)],
        2026: [(1, 4), (2, 14), (2, 28), (5, 9), (9, 20), (10, 10)],
        2027: [(1, 31), (2, 14), (5, 8), (9, 26), (10, 9)],
    ]

    /// 某天是不是放假日或调休上班日。表里没有的年份返回 nil。
    static func statutoryDay(for date: Date) -> StatutoryDay? {
        // API 缓存优先（2.6 起）：已同步的年份以接口数据为准，没同步的走内置表。
        if let override = HolidayAPIService.statutoryDayOverride(for: date) { return override }
        let comps = gregorian.dateComponents([.year, .month, .day], from: date)
        guard let year = comps.year, let month = comps.month, let day = comps.day,
              let holidays = statutoryHolidays[year] else { return nil }
        for (name, sm, sd, em, ed) in holidays {
            let afterStart = (month > sm) || (month == sm && day >= sd)
            let beforeEnd = (month < em) || (month == em && day <= ed)
            if afterStart && beforeEnd { return .holiday(name: name) }
        }
        if let workdays = statutoryWorkdays[year],
           workdays.contains(where: { $0 == month && $1 == day }) {
            return .workday
        }
        return nil
    }

    /// 休/班标志：0 普通，1 调休上班，2 放假（小历的 worktime 字段）。
    static func worktime(for date: Date) -> Int {
        switch statutoryDay(for: date) {
        case .holiday: return 2
        case .workday: return 1
        case nil: return 0
        }
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

    /// 按周首日排好的星期头，如周首日是周一时返回 ["周一", … "周日"]。
    static func weekdaySymbols() -> [String] {
        let names = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let start = AppSettings.readWeekStartDay() // 0 周日，1 周一，6 周六
        return (0..<7).map { names[(start + $0) % 7] }
    }

    /// 一年中的第几周（1 月 1 日所在周为第 1 周）。
    static func weekOfYear(for date: Date) -> Int {
        gregorian.component(.weekOfYear, from: date)
    }

    static func monthTitle(for date: Date) -> String {
        let y = gregorian.component(.year, from: date)
        let m = gregorian.component(.month, from: date)
        return "\(y) / \(m)"
    }

    static func fullGregorianString(for date: Date) -> String {
        let y = gregorian.component(.year, from: date)
        let m = gregorian.component(.month, from: date)
        let d = gregorian.component(.day, from: date)
        return "\(y)年\(m)月\(d)日 \(weekdayName(for: date))"
    }

    /// 相对今天，如“今天”“明天”“昨天”“2天后”“3天前”。
    static func relativeDayText(for date: Date) -> String {
        let today = gregorian.startOfDay(for: Date())
        let day = gregorian.startOfDay(for: date)
        let diff = gregorian.dateComponents([.day], from: today, to: day).day ?? 0
        switch diff {
        case 0: return "今天"
        case 1: return "明天"
        case -1: return "昨天"
        case 2...: return "\(diff)天后"
        default: return "\(-diff)天前"
        }
    }

    /// 某个月的日历格子：从周首日开始的整周，含上月、下月补齐的天。
    static func monthGridDays(for monthDate: Date) -> [Date] {
        let comps = gregorian.dateComponents([.year, .month], from: monthDate)
        guard let first = gregorian.date(from: comps) else { return [] }
        let firstWeekday = gregorian.component(.weekday, from: first) // 1 = 周日
        let start = AppSettings.readWeekStartDay() + 1 // 1 周日，2 周一，7 周六
        let leading = (firstWeekday - start + 7) % 7
        guard let gridStart = gregorian.date(byAdding: .day, value: -leading, to: first),
              let daysInMonth = gregorian.range(of: .day, in: .month, for: first)?.count else { return [] }
        let total = ((leading + daysInMonth + 6) / 7) * 7
        return (0..<total).compactMap { gregorian.date(byAdding: .day, value: $0, to: gridStart) }
    }

    /// 把月历格子按周切开，每周 7 天。
    static func monthWeeks(for monthDate: Date) -> [[Date]] {
        let days = monthGridDays(for: monthDate)
        return stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
    }

    /// 某天所在的那一周（从周首日开始，7 天）。
    static func weekContaining(_ date: Date) -> [Date] {
        let weekday = gregorian.component(.weekday, from: date) // 1 = 周日
        let start = AppSettings.readWeekStartDay() + 1
        let offset = (weekday - start + 7) % 7
        guard let weekStart = gregorian.date(byAdding: .day, value: -offset, to: gregorian.startOfDay(for: date)) else { return [] }
        return (0..<7).compactMap { gregorian.date(byAdding: .day, value: $0, to: weekStart) }
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
