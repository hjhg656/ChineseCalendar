import Foundation
import SwiftUI
import WidgetKit
import UIKit

/// App 和小组件共用的设置。存在 App Groups 的共享容器里，
/// 这样 App 里改了颜色和小组件背景，小组件那边也能读到。
/// 注意：共享容器要 App Groups 权限才生效；如果签名时没带这个权限
/// （比如有的第三方签名工具没注入），读到的就是 nil，这时用 .standard
/// 做后备，App 和小组件就各用各的默认值，小组件本身不会坏。
///
/// 设置键按小历的 AppConfigs 结构来：颜色 9 项（各有深色版）、
/// 尺寸 4 项（滑杆）、开关与值若干。颜色存 16 进制字符串，如 "#E5484D"。
enum AppSettings {

    static let groupID = "group.com.example.ChineseCalendar"

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: groupID) ?? .standard
    }

    // MARK: - 颜色（小历设置面板“颜色”组的顺序）

    struct AppColorSetting: Identifiable {
        let id: String          // UserDefaults 键（浅色）；深色版是 id + "Dark"
        let name: String        // 界面上显示的名字
        let defaultHex: String
    }

    static let colorSettings: [AppColorSetting] = [
        AppColorSetting(id: "appThemeColor", name: "主题背景", defaultHex: "#E5484D"),
        AppColorSetting(id: "widgetBGColor", name: "通知中心背景", defaultHex: "#FFFFFF"),
        AppColorSetting(id: "calendarGridColor", name: "一般日期", defaultHex: "#333333"),
        AppColorSetting(id: "calendarWeekendColor", name: "周末日期", defaultHex: "#D64541"),
        AppColorSetting(id: "calendarHolidayColor", name: "节日日期", defaultHex: "#5B7C99"),
        AppColorSetting(id: "calendarTodayColor", name: "当前日期", defaultHex: "#E5484D"),
        AppColorSetting(id: "calendarEventColor", name: "系统事件", defaultHex: "#3B82F6"),
        AppColorSetting(id: "calendarWorkColor", name: "加班日期", defaultHex: "#E67E22"),
        AppColorSetting(id: "calendarFreeColor", name: "休假日期", defaultHex: "#E5484D"),
    ]

    /// 读颜色的 16 进制值；深色模式读深色版，没存过就用浅色版的值。
    static func colorHex(forKey key: String, colorScheme: ColorScheme) -> String {
        let darkKey = key + "Dark"
        if colorScheme == .dark, let dark = sharedDefaults.string(forKey: darkKey) {
            return dark
        }
        if let hex = sharedDefaults.string(forKey: key) { return hex }
        return colorSettings.first(where: { $0.id == key })?.defaultHex ?? "#333333"
    }

    static func setColorHex(_ hex: String, forKey key: String) {
        sharedDefaults.set(hex, forKey: key)
    }

    static func color(forKey key: String, colorScheme: ColorScheme) -> Color {
        Color(hex: colorHex(forKey: key, colorScheme: colorScheme))
    }

    // MARK: - 尺寸（滑杆）

    static let calendarWidthScaleKey = "calendarWidthScale"
    static let calendarHeightScaleKey = "calendarHeightScale"
    static let fontScaleKey = "fontScale"
    static let positionScaleKey = "positionScale"

    // MARK: - 开关

    static let showWeekKey = "showWeek"                       // 显示周数
    static let useSingleLineModeKey = "useSingleLineMode"     // 只显示本周
    static let hideOtherDaysKey = "hideOtherDays"             // 隐藏非本月日期
    static let hideHolidaysKey = "hideHolidays"               // 隐藏法定节假日（反义：开 = 不显示）
    static let hideSystemEventsKey = "hideSystemEvents"       // 隐藏系统事件（反义）
    static let useSysEvtColorKey = "useSysEvtColor"           // 使用系统事件颜色
    static let silentModeKey = "silentMode"                   // 按键音效（反义：开 = 静音）
    static let todayModeKey = "todayMode"                     // 默认展开今日
    static let useBlackFontKey = "useBlackFont"               // 使用更粗的字体
    static let receivePushKey = "receivePush"                 // 接收节假日推送
    static let displayCompletedRemindersKey = "displayCompletedReminders" // 显示已完成的提醒事项
    static let shouldShowSubTitleKey = "shouldShowSubTitle"   // 显示副标题（农历/节日小字）
    static let enableCloudKey = "enableCloud"                 // 开启 iCloud 同步

    // MARK: - 值

    static let weekStartDayKey = "weekStartDay"   // 0 = 周日，1 = 周一，6 = 周六
    static let pushTimeKey = "pushTime"           // 如 "08:00"

    // MARK: - 小组件背景（沿用 v1.1 的透明方案）

    static let widgetBackgroundKey = "widgetBackground"
    static let widgetOpacityKey = "widgetOpacity"

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

    /// 小组件用的主题色（appThemeColor）。
    static func readThemeColor() -> Color {
        color(forKey: "appThemeColor", colorScheme: .light)
    }

    static func readWeekStartDay() -> Int {
        let value = sharedDefaults.integer(forKey: weekStartDayKey)
        return (value == 1 || value == 6) ? value : 0
    }

    static func readFontScale() -> Double {
        let value = sharedDefaults.double(forKey: fontScaleKey)
        return value <= 0 ? 1.0 : min(max(value, 0.8), 1.3)
    }

    /// 还原所有设置（清除全部设置键，恢复默认值）。
    static func resetAll() {
        var keys: [String] = []
        for setting in colorSettings {
            keys.append(setting.id)
            keys.append(setting.id + "Dark")
        }
        keys += [calendarWidthScaleKey, calendarHeightScaleKey, fontScaleKey, positionScaleKey,
                 showWeekKey, useSingleLineModeKey, hideOtherDaysKey, hideHolidaysKey,
                 hideSystemEventsKey, useSysEvtColorKey, silentModeKey, todayModeKey,
                 useBlackFontKey, receivePushKey, displayCompletedRemindersKey,
                 shouldShowSubTitleKey, enableCloudKey, weekStartDayKey, pushTimeKey,
                 widgetBackgroundKey, widgetOpacityKey]
        for key in keys {
            sharedDefaults.removeObject(forKey: key)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - 16 进制颜色

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b: Double
        if cleaned.count == 6 {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        } else {
            r = 0.2; g = 0.2; b = 0.2
        }
        self.init(red: r, green: g, blue: b)
    }

    /// 颜色转 "#RRGGBB"，存进 UserDefaults。
    func toHex() -> String {
        #if os(iOS)
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        #else
        return "#333333"
        #endif
    }
}
