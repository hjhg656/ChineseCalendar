import SwiftUI

struct ContentView: View {
    @State private var displayedMonth: Date = Date()
    @State private var selectedDate: Date = Date()
    @State private var showSettings = false

    @AppStorage("weekStartsOnMonday") private var weekStartsOnMonday = false
    @AppStorage("showSolarTerm") private var showSolarTerm = true
    @AppStorage("showWorkStatus") private var showWorkStatus = true

    private var weekdays: [String] {
        weekStartsOnMonday
            ? ["一", "二", "三", "四", "五", "六", "日"]
            : ["日", "一", "二", "三", "四", "五", "六"]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                todayCard

                // 月份切换
                HStack {
                    Button { displayedMonth = ChineseCalendarHelper.addingMonth(-1, to: displayedMonth) } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                    Text(ChineseCalendarHelper.monthTitle(for: displayedMonth))
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    Button { displayedMonth = ChineseCalendarHelper.addingMonth(1, to: displayedMonth) } label: {
                        Image(systemName: "chevron.right")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 8)

                // 星期头
                HStack(spacing: 0) {
                    ForEach(weekdays, id: \.self) { w in
                        Text(w)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 6)

                // 月历格子
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                    ForEach(ChineseCalendarHelper.monthGridDays(for: displayedMonth, weekStartsOnMonday: weekStartsOnMonday), id: \.self) { day in
                        dayCell(day)
                    }
                }
                .padding(.horizontal, 4)

                // 选中那天的详情
                dayDetail
                    .padding(.top, 12)

                Spacer()
            }
            .padding(.horizontal, 8)
            .navigationTitle("中国日历")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("今天") {
                        displayedMonth = Date()
                        selectedDate = Date()
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    // MARK: - 今天卡片

    private var todayCard: some View {
        let today = Date()
        return VStack(spacing: 4) {
            Text(ChineseCalendarHelper.fullGregorianString(for: today))
                .font(.headline)
            Text(ChineseCalendarHelper.lunarFullString(for: today))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                if let festival = ChineseCalendarHelper.festival(for: today) {
                    Text(festival)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
                if showSolarTerm, let term = ChineseCalendarHelper.solarTerm(for: today) {
                    Text(term)
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
                if showWorkStatus, let status = ChineseCalendarHelper.workStatus(for: today) {
                    Text(status)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(status == "休" ? Color.red : Color.blue, in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding(.vertical, 8)
    }

    // MARK: - 格子

    private func dayCell(_ day: Date) -> some View {
        let inMonth = ChineseCalendarHelper.month(of: day) == ChineseCalendarHelper.month(of: displayedMonth)
        let isToday = ChineseCalendarHelper.isToday(day)
        let isSelected = ChineseCalendarHelper.isSameDay(day, selectedDate)
        let festival = ChineseCalendarHelper.festival(for: day)
        let term = showSolarTerm ? ChineseCalendarHelper.solarTerm(for: day) : nil
        let status = showWorkStatus ? ChineseCalendarHelper.workStatus(for: day) : nil

        return Button {
            selectedDate = day
            if !inMonth { displayedMonth = day }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 1) {
                    Text("\(ChineseCalendarHelper.gregorian.component(.day, from: day))")
                        .font(.body)
                        .fontWeight(isToday ? .bold : .regular)
                    Text(festival ?? term ?? ChineseCalendarHelper.lunarShortString(for: day))
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundStyle(
                            festival != nil ? Color.red :
                            term != nil ? Color.orange : Color.secondary
                        )
                }
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    isSelected ? Color.accentColor.opacity(0.2) :
                        isToday ? Color.red.opacity(0.12) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isToday ? Color.red : Color.clear, lineWidth: 1)
                )
                .opacity(inMonth ? 1 : 0.35)

                if let status {
                    Text(status)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(status == "休" ? Color.red : Color.blue, in: Capsule())
                        .offset(x: -2, y: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    // MARK: - 详情

    private var dayDetail: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(ChineseCalendarHelper.fullGregorianString(for: selectedDate))
                .font(.headline)
            Text("农历  \(ChineseCalendarHelper.lunarFullString(for: selectedDate))")
                .font(.subheadline)

            if let festival = ChineseCalendarHelper.festival(for: selectedDate) {
                Text("节日  \(festival)")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
            if let term = ChineseCalendarHelper.solarTerm(for: selectedDate) {
                Text("节气  \(term)")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
            if let status = ChineseCalendarHelper.workStatus(for: selectedDate) {
                Text(status == "休" ? "今天放假" : "今天调休上班")
                    .font(.subheadline)
                    .foregroundStyle(status == "休" ? .red : .blue)
            } else {
                Text(ChineseCalendarHelper.isWorkday(selectedDate) ? "工作日" : "周末")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("把这个 App 加到主屏幕小组件，每天不用打开 App 也能看到农历。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 设置

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("weekStartsOnMonday") private var weekStartsOnMonday = false
    @AppStorage("showSolarTerm") private var showSolarTerm = true
    @AppStorage("showWorkStatus") private var showWorkStatus = true

    var body: some View {
        NavigationStack {
            Form {
                Section("日历显示") {
                    Toggle("周起始于周一", isOn: $weekStartsOnMonday)
                    Toggle("显示二十四节气", isOn: $showSolarTerm)
                    Toggle("显示休/班标记", isOn: $showWorkStatus)
                }

                Section("关于") {
                    LabeledContent("版本", value: "1.1")
                    Text("法定节假日数据来源：国务院办公厅 2026 / 2027 年放假安排通知。节气为近似日期。")
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
}

#Preview {
    ContentView()
}
