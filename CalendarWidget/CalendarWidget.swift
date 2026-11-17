import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let now = Date()
        let entry = SimpleEntry(date: now)
        // 每天午夜后刷新一次。
        let nextMidnight = Calendar.current.startOfDay(for: now).addingTimeInterval(24 * 60 * 60)
        let timeline = Timeline(entries: [entry], policy: .after(nextMidnight))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct CalendarWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    // 小组件背景和主题色从 App 设置里读（App Groups 共享设置）。
    private var themeColor: Color {
        AppSettings.readThemeColor()
    }

    private var isTransparent: Bool {
        AppSettings.readWidgetBackground() == AppSettings.widgetBackgroundTransparent
    }

    private var backgroundColor: Color {
        if isTransparent { return .clear }
        return themeColor.opacity(AppSettings.readWidgetOpacity())
    }

    /// 透明背景时用实测文字色（标题/数字 #404040，副行 #A6A6A6）；主题色背景时用白色，红色底上看得清。
    private var primaryText: Color { isTransparent ? AppSettings.ink : .white }
    private var secondaryText: Color { isTransparent ? AppSettings.sublineGrey : .white.opacity(0.85) }
    private var accentText: Color { isTransparent ? themeColor : .white }

    var body: some View {
        switch family {
        case .systemMedium:
            mediumView
        default:
            smallView
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
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(themeColor, in: Capsule())
                }
            }
            Text(WidgetLunarHelper.weekdayShortName(for: date))
                .font(.subheadline)
                .foregroundStyle(secondaryText)
            Spacer()
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
                                .foregroundStyle(isToday ? .white : primaryText)
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
            Spacer()
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
        return URL(string: "chinesecalendar://\(y)/\(m)/\(d)")!
    }
}

struct CalendarWidget: Widget {
    let kind: String = "CalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CalendarWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("中国日历")
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
    SimpleEntry(date: Date())
}

#Preview(as: .systemMedium) {
    CalendarWidget()
} timeline: {
    SimpleEntry(date: Date())
}
