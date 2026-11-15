# 中国日历 ChineseCalendar

按中国农历来的日历 App：月历上每天都标公历日期和农历日子，点一天能看到完整的农历、天干地支、生肖和节日。还能加到 iPhone 主屏幕小组件，不用打开 App 就能看到今天的农历。

## 功能

- 月历：公历大字 + 农历小字，初一显示月份（如“九月”“冬月”），节日那天显示节日名（春节、元宵、端午、中秋等）
- 法定节假日：2026 年放假安排（国务院办公厅国办发明电〔2025〕7 号），放假日标“休”、调休上班日标“班”，点一天能看到是哪个假期
- 周数：每行前面显示第几周，详情里也写第几周
- 只显示本周、隐藏非本月日期：设置里开关
- 点一天：显示完整公历日期、星期、第几周、农历（天干地支年 + 农历月日 + 生肖年）、节日、法定节假日
- 系统日历和提醒事项：允许之后，月历上有日程的那天下面有个小点，点一天能看到当天的日程和到期的提醒；只读，不会新建、修改或删除
- 设置（左上角齿轮）：主题色（中国红/橙/绿/蓝/紫/棕）、字号（小/中/大）、日期加粗、日历显示开关、小组件背景
- 小组件（WidgetKit）：小尺寸显示今天的公历、星期、农历、生肖；中尺寸显示今天起未来 7 天，每天公历 + 农历 / 节日；每天午夜自动刷新

## 小组件怎么加

装好 App 之后，在主屏幕长按空白处 → 左上角 + → 搜“中国日历”→ 选小尺寸或中尺寸 → 添加。长按已添加的小组件可以换尺寸。

## 小组件透明

设置 → 小组件 → 小组件背景，选“透明”或“主题色”；主题色下面还有个不透明度滑块（30%–100%）。

实现上：WidgetKit 没有真正的系统级透明，透明是靠 containerBackground 用 clear 实现的，壁纸会透出来，效果上就是透明；主题色就是主题色加你选的不透明度。

注意：App 里的设置是靠 App Groups 共享容器同步到小组件的，签名时要带上这个权限才生效。用 Xcode 个人账号签一般没问题；如果用第三方签名工具签完发现设置同步不过去（小组件一直是默认的主题色背景），就是签名时没带上 App Groups 权限，小组件本身还是能正常用的。

## 怎么跑起来

环境：Mac + Xcode 15 或更新，iOS 17 或更新的真机。

1. 直接双击 `ChineseCalendar.xcodeproj` 打开工程
2. 选中项目 → Target → Signing & Capabilities：Team 选你自己的 Apple ID（免费个人账号就行），Bundle Identifier 把默认的 `com.example.ChineseCalendar` 改成你自己的（必须是全网唯一的）；小组件扩展的 Bundle Identifier 会自动跟着改（`你的 Bundle ID.CalendarWidgetExtension`）
3. 顶部设备栏选你的手机，点 Run（▶）

## 打包成 IPA

1. 顶部设备栏不要选手机，选 **Any iOS Device (arm64)**
2. 菜单 Product → Archive，等编译完成，自动弹出 Organizer
3. 点 Distribute App → 选 **Development** → 一路 Next → Export，得到 `.ipa` 文件

注意：
- 免费个人账号签名的 App **7 天过期**，过期后要重新打包安装。
- 这个 IPA 是**未签名**的，不能直接装，要用 LCSign / AltStore 免费签一次再装。

## 没有 Mac 怎么办

和剪贴板 App 一样，用 GitHub 免费的 macOS 云机器编译：

1. 注册一个 GitHub 账号，新建一个公开仓库
2. 把这个工程的所有文件（包括 `.github` 这个隐藏文件夹）都传到仓库里，仓库根目录要能直接看到 `ChineseCalendar.xcodeproj` 和 `.github`
3. 打开仓库顶部的 **Actions** 标签页 → 左边选 **Build IPA** → 点 **Run workflow**
4. 等变绿之后，点进去页面最下面 **Artifacts** 里的 `ChineseCalendar-unsigned-ipa` 下载，解压得到 `ChineseCalendar-unsigned.ipa`

## 文件说明

```
ChineseCalendar/
├── ChineseCalendarApp.swift        App 入口
├── ChineseCalendar.entitlements    App Groups 权限（和小组件共享设置）
├── Models/
│   ├── ChineseCalendarHelper.swift 农历换算 + 法定节假日（2026）+ 周数
│   ├── SharedSettings.swift        App 和小组件共用的设置（主题色、字号、小组件背景）
│   └── EventStore.swift            读系统日历和提醒事项（EventKit，只读）
└── Views/
    ├── ContentView.swift           月历主界面 + 日期详情
    └── SettingsView.swift          设置：外观、日历显示、小组件背景、系统日历权限
CalendarWidget/
├── CalendarWidget.swift            小组件：今日 + 未来 7 天，小/中两个尺寸，透明/主题色背景
├── LunarHelper.swift               小组件用的农历换算（扩展是独立 target，放一份精简版）
├── CalendarWidget.entitlements     App Groups 权限
└── Info.plist                      小组件扩展的 Info.plist
```

## 说明

- 农历用 iOS 自带的中国农历（`Calendar.Identifier.chinese`）换算，闰月、天干地支、生肖都按这个来。
- 法定节假日只写了 2026 年（国办发明电〔2025〕7 号），2027 年的安排出来后要更新 `ChineseCalendarHelper` 里的表。
- 节气没有单独列出来，节日按农历月日算（春节、元宵、端午、七夕、中秋、重阳、腊八、除夕等），再加元旦、劳动节、国庆节三个公历节日。
- 系统日历和提醒事项只读不写；iCloud 同步、节假日推送、微信分享暂不支持。
- 数据全部在本地算，不联网、不上传。
