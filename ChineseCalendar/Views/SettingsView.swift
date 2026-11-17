import SwiftUI
import WidgetKit
import UIKit

/// 设置面板：颜色 9 行 / 布局 4 滑杆 / 偏好设置 / 小组件 / 其他 5 行。
/// 底部四行入口（颜色/布局/偏好设置/其他）打开时定位到对应分组。
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(AppSettings.fontScaleKey, store: AppSettings.sharedDefaults) private var fontScale = 1.0
    @AppStorage(AppSettings.calendarWidthScaleKey, store: AppSettings.sharedDefaults) private var widthScale = 1.0
    @AppStorage(AppSettings.calendarHeightScaleKey, store: AppSettings.sharedDefaults) private var heightScale = 1.0
    @AppStorage(AppSettings.positionScaleKey, store: AppSettings.sharedDefaults) private var positionScale = 0.5

    @AppStorage(AppSettings.showWeekKey, store: AppSettings.sharedDefaults) private var showWeek = false
    @AppStorage(AppSettings.useSingleLineModeKey, store: AppSettings.sharedDefaults) private var weekOnly = false
    @AppStorage(AppSettings.hideOtherDaysKey, store: AppSettings.sharedDefaults) private var hideOtherDays = false
    @AppStorage(AppSettings.hideHolidaysKey, store: AppSettings.sharedDefaults) private var hideHolidays = false
    @AppStorage(AppSettings.hideSystemEventsKey, store: AppSettings.sharedDefaults) private var hideSystemEvents = false
    @AppStorage(AppSettings.useSysEvtColorKey, store: AppSettings.sharedDefaults) private var useSysEvtColor = true
    @AppStorage(AppSettings.silentModeKey, store: AppSettings.sharedDefaults) private var silentMode = false
    @AppStorage(AppSettings.todayModeKey, store: AppSettings.sharedDefaults) private var todayMode = true
    @AppStorage(AppSettings.useBlackFontKey, store: AppSettings.sharedDefaults) private var useBlackFont = false
    @AppStorage(AppSettings.receivePushKey, store: AppSettings.sharedDefaults) private var receivePush = false
    @AppStorage(AppSettings.displayCompletedRemindersKey, store: AppSettings.sharedDefaults) private var displayCompletedReminders = false
    @AppStorage(AppSettings.shouldShowSubTitleKey, store: AppSettings.sharedDefaults) private var showSubTitle = true
    @AppStorage(AppSettings.enableCloudKey, store: AppSettings.sharedDefaults) private var enableCloud = false

    @ObservedObject var eventStore: EventStore
    var initialSection: String = "color"

    @State private var colorPickerSetting: AppSettings.AppColorSetting? = nil
    @State private var showRestoreConfirm = false
    @State private var showClearDone = false
    @State private var showPushUpdate = false
    @State private var pushUpdateMessage = ""
    @State private var isSyncingHolidays = false
    @State private var showRateNote = false

    /// 已同步的年份说明（没同步过就提示内置表的范围）。
    private var holidayCacheNote: String {
        let years = HolidayAPIService.cachedYearNumbers()
        if years.isEmpty {
            return "内置节假日表覆盖 2025–2027 年；2028 年的安排公布后点上面的按钮同步。"
        }
        return "已从接口同步：" + years.map { "\($0) 年" }.joined(separator: "、") + "。内置表覆盖 2025–2027 年。"
    }

    /// “更新节日推送”：真的去接口拉下一年的放假安排（2.6 起，不再只是弹提示）。
    private func syncHolidays() {
        guard !isSyncingHolidays else { return }
        isSyncingHolidays = true
        Task {
            pushUpdateMessage = await HolidayAPIService.syncNextYear()
            isSyncingHolidays = false
            showPushUpdate = true
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                Form {
                    // MARK: - 颜色（9 行）
                    Section("颜色") {
                        ForEach(AppSettings.colorSettings) { setting in
                            Button {
                                colorPickerSetting = setting
                            } label: {
                                HStack {
                                    Text(setting.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(AppSettings.color(forKey: setting.id, colorScheme: colorScheme))
                                        .frame(width: 28, height: 28)
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .id("color")

                    // MARK: - 布局（4 滑杆）
                    Section("布局") {
                        sliderRow(title: "面板宽度", value: $widthScale, range: 0.8...1.2)
                        sliderRow(title: "面板高度", value: $heightScale, range: 0.8...1.3)
                        sliderRow(title: "元素大小", value: $fontScale, range: 0.8...1.3)
                        sliderRow(title: "面板位置", value: $positionScale, range: 0.0...1.0)
                    }
                    .id("layout")

                    // MARK: - 偏好设置
                    Section("偏好设置") {
                        NavigationLink("事件管理") {
                            EventsManagementView(eventStore: eventStore)
                        }
                        Toggle("使用系统事件颜色", isOn: $useSysEvtColor)
                        Toggle("显示周数", isOn: $showWeek)
                        Toggle("按键音效", isOn: Binding(
                            get: { !silentMode },
                            set: { silentMode = !$0 }
                        ))
                        Toggle("显示系统事件", isOn: Binding(
                            get: { !hideSystemEvents },
                            set: { hideSystemEvents = !$0 }
                        ))
                        Toggle("显示法定节假日", isOn: Binding(
                            get: { !hideHolidays },
                            set: { hideHolidays = !$0 }
                        ))
                        NavigationLink("周首日") {
                            WeekStartView()
                        }
                        Toggle("只显示本周", isOn: $weekOnly)
                        Toggle("默认展开今日", isOn: $todayMode)
                        Toggle("隐藏非本月日期", isOn: $hideOtherDays)
                        Toggle("使用更粗的字体", isOn: $useBlackFont)
                        Toggle("接收节假日推送", isOn: $receivePush)
                        NavigationLink("节假日推送时间") {
                            PushTimeView()
                        }
                        Button {
                            syncHolidays()
                        } label: {
                            HStack {
                                Text("更新节日推送")
                                if isSyncingHolidays { ProgressView() }
                            }
                        }
                        .disabled(isSyncingHolidays)
                        Text(holidayCacheNote)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Toggle("开启 iCloud 同步", isOn: $enableCloud)
                            .disabled(true)
                        Text("iCloud 同步需要苹果付费开发者账号和 CloudKit 容器，这个版本暂不支持，开关留在这里。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Toggle("显示副标题", isOn: $showSubTitle)
                        Toggle("显示已完成的提醒事项", isOn: $displayCompletedReminders)
                    }
                    .id("style")

                    // MARK: - 小组件
                    // 小组件的颜色不在 App 里改：App 里的设置传不到小组件，
                    // 因为免费签名没有 App Groups 权限（需要付费开发者账号），
                    // 这是 iOS 的限制。小组件用自己的配置：桌面长按小组件 →
                    // 编辑小组件，可以选透明还是主题色、换主题色、调不透明度。
                    Section("小组件") {
                        Text("小组件的背景和主题色在桌面上改：长按小组件 → 编辑小组件，可以选透明还是主题色、换主题色、调不透明度，改完小组件自己刷新。App 里的设置传不到小组件（免费签名没有 App Groups 权限，需要付费开发者账号），所以这里不放改颜色的开关。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("刷新小组件") {
                            WidgetCenter.shared.reloadAllTimelines()
                        }
                    }

                    // MARK: - 其他（5 行）
                    Section("其他") {
                        Button("清除缓存") {
                            WidgetCenter.shared.reloadAllTimelines()
                            showClearDone = true
                        }
                        Button("还原所有设置") {
                            showRestoreConfirm = true
                        }
                        Button("联系我们") {
                            if let url = URL(string: "https://github.com/hjhg656/ChineseCalendar") {
                                UIApplication.shared.open(url)
                            }
                        }
                        Button("赞美历历在目") {
                            showRateNote = true
                        }
                        NavigationLink("关于历历在目") {
                            AboutView()
                        }
                    }
                    .id("other")
                }
                .onAppear {
                    // 打开时定位到对应的分组。
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo(initialSection, anchor: .top)
                        }
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(item: $colorPickerSetting) { setting in
                ColorPickerSheet(setting: setting)
            }
            .confirmationDialog("确定要还原所有设置吗？", isPresented: $showRestoreConfirm, titleVisibility: .visible) {
                Button("确定还原", role: .destructive) {
                    AppSettings.resetAll()
                    dismiss()
                }
                Button("取消", role: .cancel) { }
            }
            .alert("缓存已清除", isPresented: $showClearDone) {
                Button("知道了", role: .cancel) { }
            } message: {
                Text("本 App 不存月数据缓存（每次打开现算），小组件时间线已刷新。")
            }
            .alert("更新节日推送", isPresented: $showPushUpdate) {
                Button("知道了", role: .cancel) { }
            } message: {
                Text(pushUpdateMessage)
            }
            .alert("谢谢", isPresented: $showRateNote) {
                Button("知道了", role: .cancel) { }
            } message: {
                Text("历历在目还没上架 App Store，暂时评不了分，谢谢你的喜欢。")
            }
        }
    }

    private func sliderRow(title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack {
            Text(title)
            Slider(value: value, in: range, step: 0.05)
            Text("\(Int(value.wrappedValue * 100))%")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - 颜色选择器

struct ColorPickerSheet: View {
    let setting: AppSettings.AppColorSetting
    @Environment(\.dismiss) private var dismiss
    @State private var color: Color

    init(setting: AppSettings.AppColorSetting) {
        self.setting = setting
        _color = State(initialValue: AppSettings.color(forKey: setting.id, colorScheme: .light))
    }

    /// 预设颜色（小历颜色选择器里的名字）。
    private let presets: [(String, Color)] = [
        ("黑色", .black), ("白色", .white), ("红色", Color(hex: "#E5484D")),
        ("橙色", .orange), ("黄色", .yellow), ("柠檬", Color(hex: "#A3E635")),
        ("草绿", Color(hex: "#65A30D")), ("绿色", .green), ("海蓝", Color(hex: "#0EA5E9")),
        ("蓝色", .blue), ("紫色", .purple), ("深紫", Color(hex: "#6D28D9")),
        ("粉红", Color(hex: "#EC4899")), ("金色", Color(hex: "#D4AF37")),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ColorPicker("自定义颜色", selection: $color)
                    .padding()
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                    ForEach(presets, id: \.0) { preset in
                        Button {
                            color = preset.1
                        } label: {
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(preset.1)
                                    .frame(width: 28, height: 28)
                                    .overlay(Circle().stroke(Color.secondary.opacity(0.4), lineWidth: 1))
                                Text(preset.0)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                Spacer()
            }
            .navigationTitle(setting.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        AppSettings.setColorHex(color.toHex(), forKey: setting.id)
                        WidgetCenter.shared.reloadAllTimelines()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - 事件管理子页

struct EventsManagementView: View {
    @ObservedObject var eventStore: EventStore

    var body: some View {
        Form {
            Section("权限") {
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

            Section("显示的日历") {
                ForEach(eventStore.eventCalendars(), id: \.calendarIdentifier) { calendar in
                    Toggle(calendar.title, isOn: Binding(
                        get: { !eventStore.hiddenCalendarIDs.contains(calendar.calendarIdentifier) },
                        set: { shown in
                            var hidden = eventStore.hiddenCalendarIDs
                            if shown { hidden.remove(calendar.calendarIdentifier) }
                            else { hidden.insert(calendar.calendarIdentifier) }
                            eventStore.hiddenCalendarIDs = hidden
                            eventStore.loadEvents(for: Date())
                        }
                    ))
                }
            }

            Section("显示的提醒事项列表") {
                ForEach(eventStore.reminderCalendars(), id: \.calendarIdentifier) { calendar in
                    Toggle(calendar.title, isOn: Binding(
                        get: { !eventStore.hiddenReminderListIDs.contains(calendar.calendarIdentifier) },
                        set: { shown in
                            var hidden = eventStore.hiddenReminderListIDs
                            if shown { hidden.remove(calendar.calendarIdentifier) }
                            else { hidden.insert(calendar.calendarIdentifier) }
                            eventStore.hiddenReminderListIDs = hidden
                            eventStore.loadReminderDays(for: Date())
                        }
                    ))
                }
            }
        }
        .navigationTitle("事件管理")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func accessText(_ state: EventStore.AccessState) -> String {
        switch state {
        case .unknown: return "未询问"
        case .granted: return "已允许"
        case .denied: return "已拒绝"
        }
    }
}

// MARK: - 周首日选择

struct WeekStartView: View {
    @AppStorage(AppSettings.weekStartDayKey, store: AppSettings.sharedDefaults) private var weekStartDay = 0

    var body: some View {
        Form {
            Picker("周首日", selection: $weekStartDay) {
                Text("周日").tag(0)
                Text("周一").tag(1)
                Text("周六").tag(6)
            }
            .pickerStyle(.inline)
        }
        .navigationTitle("周首日")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 节假日推送时间

struct PushTimeView: View {
    @AppStorage(AppSettings.pushTimeKey, store: AppSettings.sharedDefaults) private var pushTime = "08:00"

    @State private var time = Date()

    var body: some View {
        Form {
            DatePicker("推送时间", selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .onChange(of: time) { _, newValue in
                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    formatter.dateFormat = "HH:mm"
                    pushTime = formatter.string(from: newValue)
                }
            Text("推送时间存在本地。这个版本没有推送服务器，时间只用来记录你的偏好，更新节日推送时按内置表检查。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .navigationTitle("节假日推送时间")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "HH:mm"
            if let date = formatter.date(from: pushTime) {
                time = date
            }
        }
    }
}

// MARK: - 关于

struct AboutView: View {
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("2.8")
                        .foregroundStyle(.secondary)
                }
                Text("历历在目：按小历的界面与功能重建的中国农历日历。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("数据来源") {
                Text("法定节假日与调休：2025 年国办发明电〔2024〕12 号、2026 年国办发明电〔2025〕7 号、2027 年国办发明电〔2026〕10 号。农历用 iPhone 自带的中国农历换算；24 节气按年内置日期表。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("暂不支持：iCloud 同步、节假日推送服务器、微信分享、Apple Watch 端。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section {
                ShareLink(item: "历历在目 - 小而美的日历", preview: SharePreview("分享历历在目")) {
                    Label("分享历历在目", systemImage: "square.and.arrow.up")
                }
            }
        }
        .navigationTitle("关于历历在目")
        .navigationBarTitleDisplayMode(.inline)
    }
}
