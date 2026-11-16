import SwiftUI
import UIKit

/// 处理桌面快捷操作（长按图标）：复制今天 / 查看今天 / 更新节日推送。
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        if let item = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            handleShortcut(item)
        }
        return true
    }

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        handleShortcut(shortcutItem)
        completionHandler(true)
    }

    private func handleShortcut(_ item: UIApplicationShortcutItem) {
        let action: String
        switch item.type {
        case "com.example.ChineseCalendar.copyToday": action = "copyToday"
        case "com.example.ChineseCalendar.showToday": action = "showToday"
        case "com.example.ChineseCalendar.updatePush": action = "updatePush"
        default: return
        }
        NotificationCenter.default.post(name: NSNotification.Name("ChineseCalendarShortcut"), object: nil, userInfo: ["action": action])
    }
}

@main
struct ChineseCalendarApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // 深链：chinesecalendar://年/月/日（小组件点某天跳过来）
                    guard url.scheme == "chinesecalendar",
                          let year = Int(url.host ?? ""),
                          url.pathComponents.count == 3,
                          let month = Int(url.pathComponents[1]),
                          let day = Int(url.pathComponents[2]),
                          let date = ChineseCalendarHelper.gregorian.date(from: DateComponents(year: year, month: month, day: day)) else { return }
                    NotificationCenter.default.post(name: NSNotification.Name("ChineseCalendarDeepLink"), object: nil, userInfo: ["date": date])
                }
        }
    }
}
