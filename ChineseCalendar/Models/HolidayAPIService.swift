import Foundation

/// 中国法定节假日 API 客户端：https://holiday.ailcc.com/
/// 免费、无需 key、无需注册、无需绑卡。免费额度：每 IP 每分钟 31 次、
/// 24 小时 10000 次；一年完整同步只需 12 次 batch 调用，远低于限额。
/// 数据来源：国务院办公厅放假通知（站长按官方通知维护，2027 年数据
/// 2026-11-05 已更新；2028 年官方通知未发布时接口返回空数据）。
///
/// 关键结论（2026-11-17 实测）：
/// - `GET /api/holiday/year/2026` 只返回放假日，不返回任何调休上班日，
///   所以不能用它同步全年——全年同步必须走 batch。
/// - `GET /api/holiday/batch?d=...&type=Y`（一次最多 31 个日期）：
///   `type` 字段才是全量分类：0 工作日、1 周末、2 节日、3 调休放假、4 补班；
///   `holiday` 对象只在放假日出现，调休上班日那里的 `holiday` 是 null，
///   只能看 `type` 才能认出补班日。
/// - 周末（type 1）不是法定节假日，绝不能当成“休”：对于官方通知
///   还没发布的年份（如 2028 年），info 接口会把周六/周日也标成
///   holiday=true、名字就是“周六”——本客户端只认 type 2/3/4，
///   并把“全年零条法定数据”当作“该年未发布”，拒绝保存。
/// - 2026、2027 年数据已对照 App 内置表逐日核对过：放假日、调休上班日
///   的日期与名字全部一致（2026 年 33 个放假日、6 个补班日；
///   2027 年 29 个放假日、5 个补班日）。
/// - 每次调用约 0.8–3.3 秒（本机实测 8/8 成功），只适合手动点
///   “更新节日推送”时同步一年，不适合按天实时查。
///
/// 用法（接入步骤见文件末尾注释）：
/// 1. `fetchYear(2028)` 拉取一年，成功后 `save` 进本地缓存；
/// 2. `statutoryDayOverride(for:)` 在读内置表之前先查缓存，API 有的年份
///    以 API 为准，没有的年份继续用内置表兜底。
enum HolidayAPIService {

    // MARK: - 模型（与 ChineseCalendarHelper.StatutoryDay 对应）

    /// 一天的法定安排：放假或调休上班。
    struct HolidayAPIDay: Codable, Equatable {
        let month: Int
        let day: Int
        /// true = 放假（worktime 2），false = 调休上班（worktime 1）。
        let isHoliday: Bool
        /// 清理过的节日名，如“春节”“元旦节”（去掉“（休）/（班）”后缀）。
        /// 调休上班日的名字是它补的那个节，如“春节”。
        let name: String
    }

    /// 一年的法定安排（缓存的单位）。
    struct HolidayAPIYear: Codable {
        let year: Int
        /// API 返回的 version，数据更新时变化，可用来判断缓存是否过期。
        let version: Int
        let fetchedAt: Date
        let days: [HolidayAPIDay]
    }

    enum HolidayAPIError: Error, LocalizedError {
        case invalidYear(Int)
        case network(Error)
        case badHTTPStatus(Int)
        case apiError(code: Int, message: String?)
        case decoding(Error)
        /// 该年官方通知还没发布（接口返回零条法定数据），不要覆盖内置表。
        case notPublishedYet(Int)

        var errorDescription: String? {
            switch self {
            case .invalidYear(let y): return "年份 \(y) 不在支持范围（2025–2035）"
            case .network(let e): return "网络请求失败：\(e.localizedDescription)"
            case .badHTTPStatus(let s): return "服务器返回异常状态码 \(s)"
            case .apiError(let code, let msg): return "接口返回错误 code=\(code)\(msg.map { "：\($0)" } ?? "")"
            case .decoding(let e): return "接口数据解析失败：\(e.localizedDescription)"
            case .notPublishedYet(let y): return "\(y) 年放假安排还没公布（国务院通知一般在前一年 11–12 月发布），先用内置表"
            }
        }
    }

    // MARK: - 接口

    private static let baseURL = "https://holiday.ailcc.com/api/holiday"
    /// batch 一次最多 31 个日期。
    private static let maxDatesPerRequest = 31

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    /// 拉取一年的全部法定安排（放假日 + 调休上班日）。
    /// 一年 12 次 batch 调用（每月一次），顺序执行，远低于每分钟 31 次的限额。
    /// 该年未发布时抛 `notPublishedYet`，调用方不要保存、继续用内置表。
    static func fetchYear(_ year: Int) async throws -> HolidayAPIYear {
        guard (2025...2035).contains(year) else { throw HolidayAPIError.invalidYear(year) }
        let gregorian = Calendar(identifier: .gregorian)
        var allDays: [HolidayAPIDay] = []
        var version = 0
        // 按月分 12 次拉，每次 ≤ 31 天。
        for month in 1...12 {
            let daysInMonth = gregorian.range(of: .day, in: .month, for: gregorian.date(from: DateComponents(year: year, month: month, day: 1))!)?.count ?? 31
            let dates = (1...daysInMonth).map { String(format: "%04d-%02d-%02d", year, month, $0) }
            for chunk in dates.chunked(into: maxDatesPerRequest) {
                let (days, v) = try await fetchBatch(dates: chunk)
                allDays.append(contentsOf: days)
                version = max(version, v)
            }
        }
        // 全年零条法定数据 = 该年官方通知还没发布（不是“这一年没有假”）。
        guard !allDays.isEmpty else { throw HolidayAPIError.notPublishedYet(year) }
        return HolidayAPIYear(year: year, version: version, fetchedAt: Date(), days: allDays)
    }

    // MARK: - 缓存（存在 App 设置同一个 UserDefaults 里）

    private static let cacheKeyPrefix = "holidayAPI.year."
    private static let cacheIndexKey = "holidayAPI.cachedYears"

    static func save(_ yearData: HolidayAPIYear) {
        guard let data = try? JSONEncoder().encode(yearData) else { return }
        AppSettings.sharedDefaults.set(data, forKey: cacheKeyPrefix + "\(yearData.year)")
        var years = cachedYearNumbers()
        if !years.contains(yearData.year) {
            years.append(yearData.year)
            years.sort()
            AppSettings.sharedDefaults.set(years, forKey: cacheIndexKey)
        }
    }

    static func cachedYear(_ year: Int) -> HolidayAPIYear? {
        guard let data = AppSettings.sharedDefaults.data(forKey: cacheKeyPrefix + "\(year)") else { return nil }
        return try? JSONDecoder().decode(HolidayAPIYear.self, from: data)
    }

    /// 已缓存的年份（用来在设置里显示“已同步 2028 年”等）。
    static func cachedYearNumbers() -> [Int] {
        AppSettings.sharedDefaults.array(forKey: cacheIndexKey) as? [Int] ?? []
    }

    static func clearCache(year: Int) {
        AppSettings.sharedDefaults.removeObject(forKey: cacheKeyPrefix + "\(year)")
        AppSettings.sharedDefaults.set(cachedYearNumbers().filter { $0 != year }, forKey: cacheIndexKey)
    }

    // MARK: - 合并：API 优先，内置表兜底

    /// 查某天的法定安排：先看 API 缓存（有该年的缓存才返回），
    /// 没有缓存返回 nil，调用方继续读内置表。
    /// 接入时在 `ChineseCalendarHelper.statutoryDay(for:)` 开头加：
    /// `if let override = HolidayAPIService.statutoryDayOverride(for: date) { return override }`
    static func statutoryDayOverride(for date: Date) -> ChineseCalendarHelper.StatutoryDay? {
        let gregorian = Calendar(identifier: .gregorian)
        let comps = gregorian.dateComponents([.year, .month, .day], from: date)
        guard let year = comps.year, let month = comps.month, let day = comps.day,
              let cached = cachedYear(year),
              let found = cached.days.first(where: { $0.month == month && $0.day == day }) else {
            return nil
        }
        return found.isHoliday ? .holiday(name: found.name) : .workday
    }

    /// 拉取下一年的放假安排并保存，返回给用户看的一句话。
    /// 只在用户点“更新节日推送”时调用（一次 12 次请求，不要每次打开 App 都拉）。
    static func syncNextYear() async -> String {
        let nextYear = Calendar.current.component(.year, from: Date()) + 1
        do {
            let data = try await fetchYear(nextYear)
            save(data)
            let holidays = data.days.filter { $0.isHoliday }.count
            return "已同步 \(nextYear) 年放假安排：放假 \(holidays) 天，调休上班 \(data.days.count - holidays) 天。月历里的休/班已经按新数据走了。"
        } catch {
            return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - 私有：batch 调用与解析

    /// 一次 batch 调用（≤ 31 个日期），返回当批的法定安排 + 数据版本。
    /// 响应：`{"code":0,"version":80,"holiday":{"2026-02-14":null,...},"type":{"2026-02-14":{"type":4,"name":"春节（班）"},...}}`
    /// 分类只认 `type`：0 工作日、1 周末（不是法定假，跳过）、2 节日、3 调休放假、4 补班。
    private static func fetchBatch(dates: [String]) async throws -> ([HolidayAPIDay], Int) {
        var components = URLComponents(string: baseURL + "/batch")!
        components.queryItems = [
            URLQueryItem(name: "d", value: dates.joined(separator: ",")),
            URLQueryItem(name: "type", value: "Y"),
        ]
        guard let url = components.url else { throw HolidayAPIError.invalidYear(0) }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw HolidayAPIError.network(error)
        }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw HolidayAPIError.badHTTPStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let decoded: BatchResponse
        do {
            decoded = try JSONDecoder().decode(BatchResponse.self, from: data)
        } catch {
            throw HolidayAPIError.decoding(error)
        }
        guard decoded.code == 0 else {
            throw HolidayAPIError.apiError(code: decoded.code, message: decoded.msg)
        }
        var days: [HolidayAPIDay] = []
        for key in dates {
            guard let typeEntry = decoded.type?[key] else { continue }
            let holidayEntry = decoded.holiday?[key] ?? nil
            switch typeEntry.type {
            case 2, 3:
                // 放假日：名字优先取 holiday 对象里的，去掉“（休）”后缀。
                let rawName = holidayEntry?.name ?? typeEntry.name
                days.append(HolidayAPIDay(month: month(of: key), day: day(of: key), isHoliday: true, name: cleanName(rawName)))
            case 4:
                // 调休上班日：holiday 对象是 null，名字在 type.name 里，如“春节（班）”。
                days.append(HolidayAPIDay(month: month(of: key), day: day(of: key), isHoliday: false, name: cleanName(typeEntry.name)))
            default:
                // 0 工作日、1 周末：不是法定安排，不记。
                continue
            }
        }
        return (days, decoded.version ?? 0)
    }

    /// “2026-02-14” → 2；解析失败返回 0（不会发生，key 就是传过去的日期）。
    private static func month(of dateString: String) -> Int {
        Int(dateString.split(separator: "-").dropFirst().first ?? "0") ?? 0
    }

    private static func day(of dateString: String) -> Int {
        Int(dateString.split(separator: "-").last ?? "0") ?? 0
    }

    /// 去掉名字末尾的“（休）/（班）”，如“春节（休）”→“春节”、
    /// “元旦节（休）”→“元旦节”。注意 API 的“元旦节”带“节”，
    /// 与内置表的“元旦”差一个字，显示时以这个名字为准即可。
    private static func cleanName(_ raw: String) -> String {
        raw.replacingOccurrences(of: "（休）", with: "")
            .replacingOccurrences(of: "（班）", with: "")
    }

    // MARK: - 响应模型

    private struct BatchResponse: Decodable {
        let code: Int
        let version: Int?
        let msg: String?
        /// 放假日的对象；调休上班日和普通日是 null。
        let holiday: [String: HolidayEntry?]?
        /// 全量分类（type=Y 时才返回）：0 工作日、1 周末、2 节日、3 调休放假、4 补班。
        let type: [String: TypeEntry?]?
    }

    private struct HolidayEntry: Decodable {
        let holiday: Bool
        let name: String
        let date: String
    }

    private struct TypeEntry: Decodable {
        let type: Int
        let name: String
    }
}

// MARK: - 接入步骤（给下次改代码的人）
//
// 1. 把本文件加进 App target（不要加进小组件 target）：
//    project.pbxproj 里照着 ChineseCalendarHelper.swift 的四行抄一份，
//    换成 HolidayAPIService.swift：
//    a. PBXBuildFile 增加 `XXX /* HolidayAPIService.swift in Sources */ =
//       {isa = PBXBuildFile; fileRef = YYY /* HolidayAPIService.swift */; };`
//       （XXX、YYY 用新的 24 位十六进制 ID，别和已有的重复）
//    b. PBXFileReference 增加 `YYY /* HolidayAPIService.swift */ =
//       {isa = PBXFileReference; lastKnownFileType = sourcecode.swift;
//       path = HolidayAPIService.swift; sourceTree = "<group>"; };`
//    c. Models 组（PBXGroup，path = Models）的 children 里加 YYY 那行；
//    d. App target 的 Sources 阶段（PBXSourcesBuildPhase，含
//       ChineseCalendarHelper.swift in Sources 的那个）的 files 里加 XXX 那行。
// 2. ChineseCalendarHelper.statutoryDay(for:) 开头加一行：
//    `if let override = HolidayAPIService.statutoryDayOverride(for: date) { return override }`
//    这样 API 缓存有的年份以 API 为准，没有的年份继续用内置表。
// 3. “更新节日推送”按钮（SettingsView 的 Button 和 ContentView 的
//    updatePush 快捷操作）改成：Task 里调
//    `let data = try await HolidayAPIService.fetchYear(2028)`（年份取
//    当前年 +1，若当年还没缓存也可顺带拉当年），成功后
//    `HolidayAPIService.save(data)`，提示“已同步 2028 年放假安排，共 X 天”；
//    失败时按 HolidayAPIError 的中文提示显示（未发布、网络失败等），
//    不要覆盖已有缓存和内置表。失败也要能离线用内置表。
// 4. 不覆盖的年份：API 没数据的年份（如 2028 年官方通知未发布时）
//    fetchYear 会抛 notPublishedYet，调用方不要保存空结果；
//    内置表（2025–2027）永远保留当兜底。
// 5. 限额注意：一次全年同步 12 次调用；不要在每次打开 App 时自动拉，
//    只在用户点“更新节日推送”时拉一次，并把 version 存下来，
//    下次只在 version 变化时才提示有更新。

private extension Array {
    /// 按固定大小分块，如 [1,2,3,4,5].chunked(into: 2) = [[1,2],[3,4],[5]]。
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var result: [[Element]] = []
        var index = startIndex
        while index < endIndex {
            let end = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            result.append(Array(self[index..<end]))
            index = end
        }
        return result
    }
}
