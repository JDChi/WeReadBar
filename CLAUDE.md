# CLAUDE.md

本文件是供 Claude Code 使用的项目速查；完整的架构、目录、数据约束与验证方式以 [AGENTS.md](./AGENTS.md) 为准。

## 项目概览

WeReadBar 是原生 Swift + SwiftUI 编写的 macOS 菜单栏应用：用 53 周（371 天）的 GitHub 风格热力图展示微信读书阅读数据，并呈现今日阅读、连续阅读、书架数量和当前在读。热力图和弹窗尺寸由 `UI/HeatmapLayout.swift`、`UI/Theme.swift` 统一定义；调整数值前请先确认布局。

## 开发提醒

- 使用 `os.Logger`（subsystem：`com.local.wereadbar`），不要使用 `print`。本应用是 `LSUIElement`，标准输出不会出现在常规控制台中。
- 并发边界不可混用：`WeReadClient` 是 `actor`，`StatsStore` 是 `@MainActor`。长循环中保留 `Task.checkCancellation()`。
- 修改 `project.yml` 后，执行 `xcodegen generate` 重新生成 Xcode 项目。
- 数据层变更前先阅读 [AGENTS.md 的关键约束](./AGENTS.md#关键约束请勿随意修改)：所有参数都放在网关 JSON 请求体顶层；每个请求均需携带 `skill_version: "1.0.4"`。
- API 令牌仅存于 macOS 偏好设置（`WeReadBar.apiToken`），不可从环境变量读取；菜单栏应用不保证拥有 shell 环境。

## 验证

```bash
xcodebuild -project WeReadBar.xcodeproj -scheme WeReadBar \
  -configuration Debug -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build
```

需要排查运行时问题时，可使用：

```bash
log stream --predicate 'subsystem == "com.local.wereadbar"' --info --debug
```

## 参考资料

- 原始设计记录：`~/.claude/plans/noble-beaming-locket.md`
- 上游 API 约定：`~/.agents/skills/weread-skills/`
