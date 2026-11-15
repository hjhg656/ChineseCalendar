import Foundation
import SwiftUI

/// App 和小组件共用的设置。存在 App Groups 的共享容器里，
/// 这样 App 里改了主题色和小组件背景，小组件那边也能读到。
/// 注意：共享容器要 App Groups 权限才生效；如果签名时没带这个权限
/// （比如有的第三方签名工具没注入），读到的就是 nil，这时用 .standard
/// 做后备，App 和小组件就各用各的默认值，小组件本身不会坏。
enum AppSettings {

    static let groupID = "group.com.example.ChineseCalendar"

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: groupID) ?? .standard
    }

    // MARK: - 键

    static let themeColorKey = "themeColor"
    static let fontSizeKey = "fontSize"
    static let boldTextKey = "boldText"
    static let showWeekNumbersKey = "showWeekNumbers"
    static let weekOnlyKey = "weekOnly"
    static let hideOtherMonthDaysKey = "hideOtherMonthDays"
    static let showHolidaysKey = "showHolidays"
    static let widgetBackgroundKey = "widgetBackground"
    static let widgetOpacityKey = "widgetOpacity"

    // MARK: - 主题色

    struct ThemeColor: Identifiable, Hashable {
        let id: String       // 存进 UserDefaults 的名字
        let name: String     // 界面上显示的名字
        let color: Color
    }

    static let themeColors: [ThemeColor] = [
        ThemeColor(id: "red", name: "中国红", color: .red),
        ThemeColor(id: "orange", name: "橙", color: .orange),
        ThemeColor(id: "green", name: "绿", color: .green),
        ThemeColor(id: "blue", name: "蓝", color: .blue),
        ThemeColor(id: "purple", name: "紫", color: .purple),
        ThemeColor(id: "brown", name: "棕", color: .brown),
    ]

    static func themeColor(named id: String) -> Color {
        themeColors.first(where: { $0.id == id })?.color ?? .red
    }

    // MARK: - 字号

    struct FontSizeOption: Identifiable, Hashable {
        let id: String
        let name: String
        let scale: CGFloat
    }

    static let fontSizes: [FontSizeOption] = [
        FontSizeOption(id: "small", name: "小", scale: 0.9),
        FontSizeOption(id: "medium", name: "中", scale: 1.0),
        FontSizeOption(id: "large", name: "大", scale: 1.15),
    ]

    static func fontScale(named id: String) -> CGFloat {
        fontSizes.first(where: { $0.id == id })?.scale ?? 1.0
    }

    // MARK: - 小组件背景

    /// 小组件背景。WidgetKit 没有真正的“系统级透明”，透明是靠
    /// containerBackground 用 clear 实现的，壁纸会透出来，效果上就是透明。
    static let widgetBackgroundTransparent = "transparent"
    static let widgetBackgroundTheme = "theme"

    static func readWidgetBackground() -> String {
        let value = sharedDefaults.string(forKey: widgetBackgroundKey)
        return (value == widgetBackgroundTransparent) ? widgetBackgroundTransparent : widgetBackgroundTheme
    }

    static func readWidgetOpacity() -> Double {
        let value = sharedDefaults.double(forKey: widgetOpacityKey)
        // 没存过时 double 返回 0，要当成默认值 1.0。
        return value <= 0 ? 1.0 : min(max(value, 0.3), 1.0)
    }

    static func readThemeColorName() -> String {
        sharedDefaults.string(forKey: themeColorKey) ?? "red"
    }
}
