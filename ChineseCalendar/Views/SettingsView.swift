import SwiftUI
import WidgetKit
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppSettings.themeColorKey, store: AppSettings.sharedDefaults) private var themeColorName = "red"
    @AppStorage(AppSettings.fontSizeKey, store: AppSettings.sharedDefaults) private var fontSizeName = "medium"
    @AppStorage(AppSettings.boldTextKey, store: AppSettings.sharedDefaults) private var boldText = false
    @AppStorage(AppSettings.showWeekNumbersKey, store: AppSettings.sharedDefaults) private var showWeekNumbers = true
    @AppStorage(AppSettings.weekOnlyKey, store: AppSettings.sharedDefaults) private var weekOnly = false
    @AppStorage(AppSettings.hideOtherMonthDaysKey, store: AppSettings.sharedDefaults) private var hideOtherMonthDays = false
    @AppStorage(AppSettings.showHolidaysKey, store: AppSettings.sharedDefaults) private var showHolidays = true
    @AppStorage(AppSettings.widgetBackgroundKey, store: AppSettings.sharedDefaults) private var widgetBackground = AppSettings.widgetBackgroundTheme
    @AppStorage(AppSettings.widgetOpacityKey, store: AppSettings.sharedDefaults) private var widgetOpacity = 1.0

    @ObservedObject var eventStore: EventStore

    var body: some View {
        NavigationStack {
            Form {
                Section("外观") {
                    Picker("主题色", selection: $themeColorName) {
                        ForEach(AppSettings.themeColors) { theme in
                            HStack {
                                Circle().fill(theme.color).frame(width: 20, height: 20)
                                Text(theme.name)
                            }
                            .tag(theme.id)
                        }
                    }
                    Picker("字号", selection: $fontSizeName) {
                        ForEach(AppSettings.fontSizes) { size in
                            Text(size.name).tag(size.id)
                        }
                    }
                    .pickerStyle(.segmented)
                    Toggle("日期加粗", isOn: $boldText)
                }

                Section("日历显示") {
                    Toggle("显示周数", isOn: $showWeekNumbers)
                    Toggle("只显示本周", isOn: $weekOnly)
                    Toggle("隐藏非本月日期", isOn: $hideOtherMonthDays)
                    Toggle("显示法定节假日", isOn: $showHolidays)
                }

                Section("小组件") {
                    Picker("小组件背景", selection: $widgetBackground) {
                        Text("透明").tag(AppSettings.widgetBackgroundTransparent)
                        Text("主题色").tag(AppSettings.widgetBackgroundTheme)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: widgetBackground) { _, _ in
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                    if widgetBackground == AppSettings.widgetBackgroundTheme {
                        HStack {
                            Text("不透明度")
                            Slider(value: $widgetOpacity, in: 0.3...1.0, step: 0.05)
                            Text("\(Int(widgetOpacity * 100))%")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                        .onChange(of: widgetOpacity) { _, _ in
                            WidgetCenter.shared.reloadAllTimelines()
                        }
                    }
                    Text("透明是用 clear 背景实现的，主屏幕壁纸会透出来。改完后小组件会自动刷新。这个设置靠 App Groups 同步到小组件；如果签名时没带这个权限，小组件会保持默认的主题色背景。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("系统日历和提醒事项") {
                    HStack {
                        Text("日历权限")
                        Spacer()
                        Text(accessText(eventStore.calendarAccess))
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("提醒事项权限")
                        Spacer()
                        Text(accessText(eventStore.remindersAccess))
                            .foregroundStyle(.secondary)
                    }
                    if eventStore.calendarAccess != .granted || eventStore.remindersAccess != .granted {
                        Button("允许读取系统日历和提醒事项") {
                            Task { await eventStore.requestAccess() }
                        }
                    }
                    if eventStore.calendarAccess == .denied || eventStore.remindersAccess == .denied {
                        Button("去系统设置里打开权限") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                    Text("只读你手机自带日历和提醒事项里已有的日程，不会新建、修改或删除，也不会上传。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.1")
                            .foregroundStyle(.secondary)
                    }
                    Text("法定节假日按国务院办公厅 2026 年放假安排（国办发明电〔2025〕7 号），只写了 2026 年，2027 年的安排出来后要更新。农历用 iPhone 自带的中国农历换算。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("暂不支持：iCloud 同步、节假日推送、微信分享。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func accessText(_ state: EventStore.AccessState) -> String {
        switch state {
        case .unknown: return "未询问"
        case .granted: return "已允许"
        case .denied: return "已拒绝"
        }
    }
}
