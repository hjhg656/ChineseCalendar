import SwiftUI

struct ContentView: View {
    @State private var displayedMonth: Date = Date()
    @State private var selectedDate: Date = Date()

    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 今天
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
                    ForEach(ChineseCalendarHelper.monthGridDays(for: displayedMonth), id: \.self) { day in
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("今天") {
                        displayedMonth = Date()
                        selectedDate = Date()
                    }
                }
            }
        }
    }

    // MARK: - 今天

    private var todayCard: some View {
        let today = Date()
        return VStack(spacing: 4) {
            Text(ChineseCalendarHelper.fullGregorianString(for: today))
                .font(.headline)
            Text(ChineseCalendarHelper.lunarFullString(for: today))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let festival = ChineseCalendarHelper.festival(for: today) {
                Text(festival)
                    .font(.subheadline)
                    .foregroundStyle(.red)
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
        return Button {
            selectedDate = day
            if !inMonth { displayedMonth = day }
        } label: {
            VStack(spacing: 1) {
                Text("\(ChineseCalendarHelper.gregorian.component(.day, from: day))")
                    .font(.body)
                    .fontWeight(isToday ? .bold : .regular)
                Text(festival ?? ChineseCalendarHelper.lunarShortString(for: day))
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(festival != nil ? Color.red : Color.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
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

#Preview {
    ContentView()
}
