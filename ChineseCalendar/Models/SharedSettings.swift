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
/// 设置键按小历的 AppConfigs 结构来：颜色 8 项（各有深色版）、
/// 尺寸 4 项（滑杆）、开关与值若干。颜色存 16 进制字符串，如 "#EA545D"。
enum AppSettings {

    static let groupID = "group.com.example.ChineseCalendar"

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: groupID) ?? .standard
    }

    // MARK: - 颜色（小历设置面板“颜色”组的顺序；“通知中心背景”不在这里——
    // 小组件的颜色现在由小组件自己的配置管（桌面长按 → 编辑小组件），App 里的设置
    // 传不到小组件，因为免费签名没有 App Groups 权限）

    struct AppColorSetting: Identifiable {
        let id: String          // UserDefaults 键（浅色）；深色版是 id + "Dark"
        let name: String        // 界面上显示的名字
        let defaultHex: String
    }

    static let colorSettings: [AppColorSetting] = [
        AppColorSetting(id: "appThemeColor", name: "主题背景", defaultHex: "#EA545D"),
        AppColorSetting(id: "calendarGridColor", name: "一般日期", defaultHex: "#404040"),
        AppColorSetting(id: "calendarWeekendColor", name: "周末日期", defaultHex: "#404040"),
        AppColorSetting(id: "calendarHolidayColor", name: "节日日期", defaultHex: "#708090"),
        AppColorSetting(id: "calendarTodayColor", name: "当前日期", defaultHex: "#EA545D"),
        AppColorSetting(id: "calendarEventColor", name: "系统事件", defaultHex: "#0EA5E9"),
        AppColorSetting(id: "calendarWorkColor", name: "加班日期", defaultHex: "#E67E22"),
        AppColorSetting(id: "calendarFreeColor", name: "休假日期", defaultHex: "#EA545D"),
    ]

    /// 实测色（2026-11-17 对着小历真机截图逐像素取色，1320×2868，pt = px/3）：
    /// 标题/数字 #404040，副行（农历小字/星期头）#A6A6A6，今天红圆 #EA545D，
    /// 节日蓝灰 #708090，日详情蓝标签 #1070C0，事件蓝点 #0EA5E9。
    /// ink / sublineGrey 是深色自适应的（深色下用白 / 系统次级灰），其余取自上面的设置项。
    /// 用 computed var 而不是 static let，避免小组件 extension 启动时过早创建动态 Color 出问题。
    static var ink: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? .white
                : UIColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1)
        })
    }
    static var sublineGrey: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1)
                : UIColor(red: 0.65, green: 0.65, blue: 0.65, alpha: 1)
        })
    }
    static let tagBlue = Color(hex: "1070C0")
    static let measuredRed = Color(hex: "EA545D")

    /// 实测字号（同上）：标题 23，星期头 14，日期数字 20，副行 10，今天红圆直径 36，行距 42。
    static let titleFontSize: CGFloat = 23
    static let weekdayFontSize: CGFloat = 14
    static let dayNumberFontSize: CGFloat = 20
    static let sublineFontSize: CGFloat = 10
    static let todayCircleSize: CGFloat = 36
    static let dayCellHeight: CGFloat = 42

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

    // 注意：小组件的背景/主题色/不透明度以前存在这里（App Groups 共享设置），
    // 但免费签名没有 App Groups 权限，小组件读不到 App 的设置，所以 2.5 起
    // 小组件改用自己的配置（桌面长按 → 编辑小组件），这里不再留这些键。

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
                 shouldShowSubTitleKey, enableCloudKey, weekStartDayKey, pushTimeKey]
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
