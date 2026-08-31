# AGENTS.md — WeReadBar

WeReadBar 是一个原生 Swift + SwiftUI 的 macOS 菜单栏应用，用 GitHub 风格阅读热力图与摘要卡片展示微信读书数据。它是 `LSUIElement` 应用：没有 Dock 图标，状态完全由菜单栏入口驱动。

## 快速开始

```bash
brew install xcodegen              # 首次需要：安装项目生成器
xcodegen generate                  # 根据 project.yml 生成 WeReadBar.xcodeproj
open WeReadBar.xcodeproj           # 在 Xcode 中按 Command + R 运行
```

无界面构建：

```bash
xcodebuild \
  -project WeReadBar.xcodeproj \
  -scheme WeReadBar \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  build
```

## 目录与职责

```
project.yml                         # XcodeGen 配置，项目结构的唯一来源
WeReadBar.xcodeproj/                # 由 XcodeGen 生成，可提交
WeReadBar/
  App/
    WeReadBarApp.swift              # SwiftUI 应用入口，挂接 AppDelegate
    AppDelegate.swift               # 生命周期装配：状态、弹窗和菜单栏控制器
    MenuBarController.swift         # 状态栏图标、左右键交互和右键菜单
    PopoverPresenter.swift          # NSPopover 的显示、关闭和刷新协调
    OnboardingWindowController.swift # 首次录入或更换令牌的 AppKit 窗口
  UI/
    PopoverView.swift               # 弹窗根视图与可见时轮询
    HeatmapView.swift               # 53 周阅读热力图
    HeatmapLayout.swift             # 热力图网格尺寸与列数
    Theme.swift                     # 弹窗尺寸与主题常量
    SkeletonHeatmap.swift           # 数据加载中的骨架图
    StatTile.swift                  # 摘要数字卡片
    SummaryLine.swift               # 本周合计与当前在读
    ErrorBanner.swift               # 请求失败提示
    OnboardingWindow.swift          # 录入令牌的 SwiftUI 视图
  Data/
    StatsStore.swift                # @MainActor 状态、数据编排和统计派生
    WeReadClient.swift              # actor 化的微信读书网关请求
    ReadingDay.swift                # 日期与阅读秒数模型
    BookSummary.swift               # 当前在读投影
    ShelfResponse.swift             # /shelf/sync 解码模型
    ReadDataResponse.swift          # /readdata/detail 解码模型
  Security/
    TokenStore.swift                # UserDefaults 令牌存取
  Resources/
    Info.plist                      # LSUIElement、Bundle ID 等配置
README.md                           # 面向使用者的说明
```

## 架构

- **应用入口**：`WeReadBarApp.swift` 用 `@NSApplicationDelegateAdaptor` 挂接 `AppDelegate`；后者创建 `MenuBarController` 与 `PopoverPresenter`。左键开关弹窗，右键显示刷新、更换 API key、打开微信读书和退出菜单。
- **状态**：`StatsStore.swift` 是 `@MainActor ObservableObject`，持有 `WeReadClient` 并负责刷新管线。所有 `@Published` 属性均为 `private(set)`，视图只观察，不直接写入。
- **网络**：`WeReadClient.swift` 是 `actor`，通过 `URLSession` 访问唯一网关 `https://i.weread.qq.com/api/agent/gateway`。请求参数必须平铺在 JSON 顶层。
- **引导**：`OnboardingWindowController` 持有真正的 AppKit `NSWindow`。不要改为 SwiftUI `Window` scene；用户关闭后它无法稳定地再次显示。
- **令牌**：`TokenStore.swift` 将 bearer token 存在 macOS 偏好设置（`WeReadBar.apiToken`，位于 `com.local.wereadbar.plist`）。不要依赖环境变量或 `.zshrc`。

## 数据刷新流程

`StatsStore.performRefresh` 会：

1. 并发请求 `/shelf/sync` 与 `/readdata/detail?mode=annually`。
2. 更新书架总数与当前在读。
3. 通过 `resolveHeatmap` 解析热力图数据。
4. 生成以今天结束的 53 个周一至周日列（共 371 天）。
5. 计算今日阅读秒数、连续阅读天数和本周总时长。

优先使用年度响应中的 `dailyReadTimes`；若字段为空或缺失，则 `stitchMonthly` 从当月向前连续请求 13 个月并按 UTC+8 零点时间戳合并每日 `readTimes`。

## 关键约束（请勿随意修改）

这些约束都来自已经发生过的真实问题；修改相关代码后，必须完成下方的构建与运行日志验证。

1. 历史月份只能用 `baseTime` 查询。服务端会静默忽略 `year`、`month` 参数；参考 `WeReadClient.monthStartUTC8(for:)`。
2. 年度接口的 `dailyReadTimes` 不是必有字段。缺失时必须保留月度拼接兜底路径。
3. 所有时长字段单位都是**秒**；仅在 UI 层换算。
4. 有效阅读日的阈值是 `seconds >= 60`，不能改成 `> 0`；这与服务端 `readDays` 定义一致。
5. 书架总数等于 `books.length + albums.length + (mp ? 1 : 0)`，不可只计算书籍。
6. `stitchMonthly` 必须以固定的 `origin` 回溯；在循环中继续修改 `cursor` 会造成月份累计偏移。
7. 引导页必须使用 `OnboardingWindowController` 管理的 `NSWindow`，不能换成 SwiftUI `Window` scene。
8. 热力图是 53 列 × 7 行。`HeatmapLayout` 的单元格、间距、月标与 `Theme.popoverWidth` 共同决定 780pt 弹窗宽度；调整其中任意一个要重新核算并实际查看。
9. 年视图依赖约 13 个月的数据。改变列数时，应同步调整 `stitchMonthly` 的回溯范围和 `buildDays` 的 371 天网格。

## 常见改动位置

| 目标 | 修改位置 |
|---|---|
| 调整热力图颜色或分级 | `UI/HeatmapView.swift` |
| 调整网格尺寸或列数 | `UI/HeatmapLayout.swift` |
| 调整弹窗尺寸 | `UI/Theme.swift` |
| 调整轮询频率 | `UI/PopoverView.swift` 的 `Timer.publish` |
| 强制走月度拼接测试 | 环境变量 `WEREADBAR_FORCE_MONTHLY=1` |
| 新增 API 端点 | `Data/WeReadClient.swift` 和 `Data/` 中相应 `Decodable` 模型 |
| 更换菜单栏图标 | `App/MenuBarController.swift` |
| 清除已保存的令牌 | `defaults delete com.local.wereadbar WeReadBar.apiToken` |

## 开发约定

- **并发**：网络层使用 `actor`，状态层使用 `@MainActor`。长循环需调用 `Task.checkCancellation()`；刷新任务通过 `refreshTask` 取消旧任务后再启动新任务。
- **日志**：使用 subsystem 为 `com.local.wereadbar` 的 `os.Logger`（见 `StatsStore.swift` 中的 `wrLog`）；不要使用 `print`。
- **错误**：写入 `StatsStore.lastError`，由弹窗的 `ErrorBanner` 呈现。
- **命名**：Swift 文件使用与主类型一致的 PascalCase。`Data/` 下的网络模型只需 `Decodable`。
- **依赖**：不引入第三方依赖；仅使用 SwiftUI、AppKit、Security、Foundation 与 os。

## 冒烟验证

```bash
cd ~/develop/weread-dashboard
xcodebuild -project WeReadBar.xcodeproj -scheme WeReadBar \
  -configuration Debug -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  build 2>&1 | grep -E "error:|BUILD"
```

需要查看真实请求路径时：

```bash
killall WeReadBar 2>/dev/null
log stream --predicate 'subsystem == "com.local.wereadbar"' --info --debug --style compact &
APP="/Users/chijiaduo/Library/Developer/Xcode/DerivedData/WeReadBar-*/Build/Products/Debug/WeReadBar.app"
"$APP/Contents/MacOS/WeReadBar" &
sleep 6 && killall WeReadBar
```

日志应包含令牌加载状态、书架/年度请求状态、连续 13 次月度回退请求（若触发）、合并后的键数及 371 天的构建结果。首用或年度接口完整返回时，部分行不会出现。

## v1 范围外

- 自动更新、通知与全局快捷键
- 多账号或 API key 切换
- Sandbox、签名、公证与 App Store 上架
- 本地数据缓存（每次刷新重新请求微信读书）
- 除无界面编译检查以外的单元测试
- 自定义 App 图标与额外本地化语言
