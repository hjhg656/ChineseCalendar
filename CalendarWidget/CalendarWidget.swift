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
        AppSettings.themeColor(named: AppSettings.readThemeColorName())
    }

    private var isTransparent: Bool {
        AppSettings.readWidgetBackground() == AppSettings.widgetBackgroundTransparent
    }

    private var backgroundColor: Color {
        if isTransparent { return .clear }
        return themeColor.opacity(AppSettings.readWidgetOpacity())
    }

    /// 透明背景时用系统默认文字色；主题色背景时用白色，红色底上看得清。
    private var primaryText: Color { isTransparent ? .primary : .white }
    private var secondaryText: Color { isTransparent ? .secondary : .white.opacity(0.85) }
    private var accentText: Color { isTransparent ? .red : .white }

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
        return VStack(alignment: .leading, spacing: 2) {
            Text("\(g.component(.month, from: date))月\(g.component(.day, from: date))日")
                .font(.headline)
                .foregroundStyle(primaryText)
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
            if let festival = WidgetLunarHelper.festival(for: date) {
                Text(festival)
                    .font(.caption)
                    .foregroundStyle(accentText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .containerBackground(backgroundColor, for: .widget)
    }

    // MARK: - 中尺寸：今天 + 未来 6 天

    private var mediumView: some View {
        let g = WidgetLunarHelper.gregorian
        let today = entry.date
        let days = (0..<7).compactMap { g.date(byAdding: .day, value: $0, to: today) }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(g.component(.year, from: today))年\(g.component(.month, from: today))月")
                    .font(.headline)
                    .foregroundStyle(primaryText)
                Spacer()
                Text(WidgetLunarHelper.lunarDateString(for: today))
                    .font(.subheadline)
                    .foregroundStyle(secondaryText)
            }
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    VStack(spacing: 2) {
                        Text(WidgetLunarHelper.weekdayShortName(for: day))
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                        Text("\(g.component(.day, from: day))")
                            .font(.headline)
                            .fontWeight(g.isDateInToday(day) ? .bold : .regular)
                            .foregroundStyle(g.isDateInToday(day) ? accentText : primaryText)
                        Text(WidgetLunarHelper.festival(for: day) ?? WidgetLunarHelper.lunarShortString(for: day))
                            .font(.caption2)
                            .lineLimit(1)
                            .foregroundStyle(WidgetLunarHelper.festival(for: day) != nil ? accentText : secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            if let festival = WidgetLunarHelper.festival(for: today) {
                Text("今天 · \(festival)")
                    .font(.caption)
                    .foregroundStyle(accentText)
            } else {
                Text("\(WidgetLunarHelper.stemBranchYear(for: today)) · \(WidgetLunarHelper.zodiac(for: today))年")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .containerBackground(backgroundColor, for: .widget)
    }
}

struct CalendarWidget: Widget {
    let kind: String = "CalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CalendarWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("中国日历")
        .description("今天的公历、农历、生肖和节日。")
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
