import WidgetKit
import SwiftUI
import AppIntents

/// 小组件自己的配置（2.5 起）：桌面长按小组件 → 编辑小组件。
/// 以前小组件的颜色存在 App Groups 共享设置里，但免费签名没有 App Groups
/// 权限，小组件读不到 App 的设置，所以改颜色一直没反应。现在改用系统自带的
/// 小组件配置（存在小组件自己那边），不需要任何权限，免费签名也能用。
enum WidgetBackgroundOption: String, AppEnum {
    case transparent, theme

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "小组件背景" }
    static var caseDisplayRepresentations: [WidgetBackgroundOption: DisplayRepresentation] {
        [.transparent: "透明", .theme: "主题色"]
    }
}

enum WidgetThemeColorOption: String, AppEnum {
    case red, black, white, orange, yellow, lemon, grassGreen, green, seaBlue, blue, purple, deepPurple, pink, gold

    /// 和 App 里颜色选择器同一套预设。
    var hex: String {
        switch self {
        case .red: return "#EA545D"
        case .black: return "#000000"
        case .white: return "#FFFFFF"
        case .orange: return "#FF9500"
        case .yellow: return "#FFFF00"
        case .lemon: return "#A3E635"
        case .grassGreen: return "#65A30D"
        case .green: return "#34C759"
        case .seaBlue: return "#0EA5E9"
        case .blue: return "#007AFF"
        case .purple: return "#AF52DE"
        case .deepPurple: return "#6D28D9"
        case .pink: return "#EC4899"
        case .gold: return "#D4AF37"
        }
    }

    /// 主题色太浅时（白、黄、柠檬），压在上面的字要用深色，否则白字在浅底上看不清。
    var isLight: Bool {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: h).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        return 0.299 * r + 0.587 * g + 0.114 * b > 0.6
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "主题色" }
    static var caseDisplayRepresentations: [WidgetThemeColorOption: DisplayRepresentation] {
        [.red: "红色", .black: "黑色", .white: "白色", .orange: "橙色", .yellow: "黄色",
         .lemon: "柠檬", .grassGreen: "草绿", .green: "绿色", .seaBlue: "海蓝", .blue: "蓝色",
         .purple: "紫色", .deepPurple: "深紫", .pink: "粉红", .gold: "金色"]
    }
}

struct WidgetConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "中国日历设置" }
    static var description: IntentDescription { "设置小组件的背景和主题色。长按桌面小组件 → 编辑小组件即可修改。" }

    @Parameter(title: "背景", default: .theme)
    var background: WidgetBackgroundOption

    @Parameter(title: "主题色", default: .red)
    var themeColor: WidgetThemeColorOption

    /// 0.3～1.0，默认 1.0。系统会在编辑界面给出数字输入。
    @Parameter(title: "不透明度", default: 1.0)
    var opacity: Double
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), config: WidgetConfigIntent())
    }

    func snapshot(for configuration: WidgetConfigIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), config: configuration)
    }

    func timeline(for configuration: WidgetConfigIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let now = Date()
        let entry = SimpleEntry(date: now, config: configuration)
        // 每天午夜后刷新一次。
        let nextMidnight = Calendar.current.startOfDay(for: now).addingTimeInterval(24 * 60 * 60)
        return Timeline(entries: [entry], policy: .after(nextMidnight))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let config: WidgetConfigIntent
}

struct CalendarWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    // 小组件的背景和主题色从自己的配置里读（长按小组件 → 编辑小组件）。
    private var themeColor: Color {
        Color(hex: entry.config.themeColor.hex)
    }

    private var isTransparent: Bool {
        entry.config.background == .transparent
    }

    private var backgroundColor: Color {
        if isTransparent { return .clear }
        let opacity = min(max(entry.config.opacity, 0.3), 1.0)
        return themeColor.opacity(opacity)
    }

    /// 压在主题色上面的字：主题色深就用白字，太浅就用深色字。
    private var onThemeColor: Color {
        entry.config.themeColor.isLight ? AppSettings.ink : .white
    }

    /// 透明背景时用实测文字色（标题/数字 #404040，副行 #A6A6A6）；主题色背景时，浅主题用深色字、深主题用白色，红色底上看得清。
    private var primaryText: Color {
        if isTransparent { return AppSettings.ink }
        return entry.config.themeColor.isLight ? AppSettings.ink : .white
    }
    private var secondaryText: Color {
        if isTransparent { return AppSettings.sublineGrey }
        return entry.config.themeColor.isLight ? AppSettings.sublineGrey : .white.opacity(0.85)
    }
    private var accentText: Color {
        if isTransparent { return themeColor }
        return entry.config.themeColor.isLight ? AppSettings.ink : .white
    }

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumView
            case .systemSmall:
                smallView
            default:
                // 兜底：未知 family 也画小尺寸，避免 body 空导致系统显示占位图
                smallView
            }
        }
    }

    // MARK: - 小尺寸：今天

    private var smallView: some View {
        let date = entry.date
        let g = WidgetLunarHelper.gregorian
        let info = WidgetLunarHelper.dayInfo(for: date)
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("\(g.component(.month, from: date))月\(g.component(.day, from: date))日")
                    .font(.headline)
                    .foregroundStyle(primaryText)
                if info.worktime == 2 {
                    Text("休")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(onThemeColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(themeColor, in: Capsule())
                }
            }
            Text(WidgetLunarHelper.weekdayShortName(for: date))
                .font(.subheadline)
                .foregroundStyle(secondaryText)
            Spacer(minLength: 0)
            Text("\(g.component(.day, from: date))")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(primaryText)
            Text(WidgetLunarHelper.lunarDateString(for: date))
                .font(.subheadline)
                .foregroundStyle(primaryText)
            Text("\(WidgetLunarHelper.stemBranchYear(for: date)) · \(WidgetLunarHelper.zodiac(for: date))年")
                .font(.caption)
                .foregroundStyle(secondaryText)
            if let name = info.displayName {
                Text(name)
                    .font(.caption)
                    .foregroundStyle(accentText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .containerBackground(backgroundColor, for: .widget)
        .widgetURL(deepLink(for: date))
    }

    // MARK: - 中尺寸：一周横排 + 底部信息行（按小历截图）

    private var mediumView: some View {
        let g = WidgetLunarHelper.gregorian
        let today = entry.date
        let days = WidgetLunarHelper.weekContaining(today)
        let todayInfo = WidgetLunarHelper.dayInfo(for: today)
        return VStack(alignment: .leading, spacing: 6) {
            // 标题：2026 / 11 · 46（箭头是装饰，小组件点哪儿都打开 App）
            HStack {
                Image(systemName: "chevron.left")
                    .font(.subheadline)
                    .foregroundStyle(secondaryText)
                Spacer()
                Text("\(g.component(.year, from: today)) / \(g.component(.month, from: today)) · \(todayInfo.week)")
                    .font(.system(size: AppSettings.titleFontSize))
                    .foregroundStyle(primaryText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(secondaryText)
            }
            // 星期头
            HStack(spacing: 0) {
                ForEach(WidgetLunarHelper.weekdaySymbols(), id: \.self) { w in
                    Text(w)
                        .font(.system(size: AppSettings.weekdayFontSize))
                        .foregroundStyle(secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            // 一周 7 天横排
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    let info = WidgetLunarHelper.dayInfo(for: day)
                    let isToday = g.isDateInToday(day)
                    Link(destination: deepLink(for: day)) {
                        VStack(spacing: 2) {
                            Text("\(g.component(.day, from: day))")
                                .font(.system(size: AppSettings.dayNumberFontSize))
                                .fontWeight(isToday ? .bold : .regular)
                                .foregroundStyle(isToday ? onThemeColor : primaryText)
                                .frame(width: AppSettings.todayCircleSize, height: AppSettings.todayCircleSize)
                                .background(isToday ? themeColor : Color.clear, in: Circle())
                            Text(info.displayName ?? WidgetLunarHelper.lunarShortString(for: day))
                                .font(.system(size: AppSettings.sublineFontSize))
                                .lineLimit(1)
                                .foregroundStyle(info.hasHoliday ? accentText : secondaryText)
                            if info.worktime == 2 {
                                Text("休")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(accentText)
                            } else if info.worktime == 1 {
                                Text("班")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(accentText)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            Spacer(minLength: 0)
            // 底部信息行：红竖线 + 日期/周/干支/农历
            HStack(spacing: 8) {
                Rectangle()
                    .fill(themeColor)
                    .frame(width: 5)
                Text("\(g.component(.month, from: today))月\(g.component(.day, from: today))日 第\(todayInfo.week)周 \(WidgetLunarHelper.stemBranchYear(for: today).dropLast())(\(WidgetLunarHelper.zodiac(for: today)))年 \(WidgetLunarHelper.lunarMonthName(for: today)) \(WidgetLunarHelper.lunarDayName(for: today))")
                    .font(.subheadline)
                    .foregroundStyle(primaryText)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .containerBackground(backgroundColor, for: .widget)
    }

    /// 点小组件某天打开 App 并跳到那天：chinesecalendar://年/月/日。
    private func deepLink(for date: Date) -> URL {
        let g = WidgetLunarHelper.gregorian
        let y = g.component(.year, from: date)
        let m = g.component(.month, from: date)
        let d = g.component(.day, from: date)
        return URL(string: "chinesecalendar://\(y)/\(m)/\(d)") ?? URL(string: "chinesecalendar://")!
    }
}

struct CalendarWidget: Widget {
    let kind: String = "CalendarWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: WidgetConfigIntent.self, provider: Provider()) { entry in
            CalendarWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("历历在目")
        .description("将农历和节假日添加到桌面。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct CalendarWidgetBundle: WidgetBundle {
    var body: some Widget {
        CalendarWidget()
    }
}

#Preview(as: .systemSmall) {
    CalendarWidget()
} timeline: {
    SimpleEntry(date: Date(), config: WidgetConfigIntent())
}

#Preview(as: .systemMedium) {
    CalendarWidget()
} timeline: {
    SimpleEntry(date: Date(), config: WidgetConfigIntent())
}
