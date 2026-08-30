<div align="center">

# WeReadBar

**一个迷你的 macOS 菜单栏 app，把你的微信读书 (WeRead) 阅读数据一眼呈现。**

[📥 **下载**](../../releases/latest) · [⭐ Star](../../stargazers) · [🐛 反馈问题](../../issues)

</div>

---

## 这是什么？

WeReadBar 住在你的菜单栏里，展示：

- **一整年的热力图** —— GitHub 风格的贡献图，不过是读书版本
- **今日时长**、**当前连续天数**、**书架总数** —— 三个数字，一眼看完
- **本周合计** —— 当前 Mon–Sun 周的累计时长
- **当前在读** —— 没有别的内容时，显示正在读的书

点书本图标看弹窗。右键弹菜单（刷新 / 去阅读 / 更改 API 令牌 / 退出）。就这么多。

因为打开浏览器看 weread.qq.com 就为了查个连续天数太折腾了，所以做了这个。

![WeReadBar 弹窗预览](docs/display.png)

---

## 功能

- 📊 **一整年热力图** —— 最近 53 周每天的阅读时长，按强度上色
- 🔥 **连续天数** —— 当前的连续日（每天 ≥ 60 秒算一天）
- 📚 **书架总数** —— 书架上的书 + 专辑 + 公众号
- ⏱ **今日分钟** —— 今天到现在读了多少分钟
- 📅 **本周合计** —— 当前 Mon–Sun 周累计
- 🌍 **三语支持** — English / 简体中文 / 繁體中文（跟随系统语言）
- 🔐 **本地保存** —— API 令牌存在 macOS preferences，不弹任何密码框
- 🚫 **无 Dock 图标、无系统托盘菜单** —— 不需要时完全隐形

---

## 安装

需要 **macOS 14 (Sonoma)** 或更新版本，以及一个微信读书账号。

1. **[下载最新 DMG](../../releases/latest)**
2. 打开 DMG，把 **WeReadBar** 拖到 **/Applications**
3. 在 /Applications 里**右键** `WeReadBar.app` → **打开** → 确认
4. 提示时粘贴 **WeRead API bearer token**（在 [weread.qq.com/r/weread-skills](https://weread.qq.com/r/weread-skills) 获取）
5. 点菜单栏的书本图标 🎉

> **为什么要右键打开？** 这个 app 没有 Apple Developer ID 签名，macOS Gatekeeper 第一次会拦下来让你确认一次。之后就正常打开了。

---

## 隐私

- **网络**：WeReadBar 只跟 `i.weread.qq.com`（微信读书官方 API 网关）通信。无埋点、无遥测、无第三方服务。
- **凭据**：API 令牌存在 macOS preferences（`~/Library/Preferences/com.local.wereadbar.plist`，键名 `WeReadBar.apiToken`），只被这个 app 读。
- **磁盘缓存**：没有。每次刷新都重新从微信读书拉。
- **源码**：完全开源。随便读、审、fork。

---

## 常见问题

<details>
<summary><b>为什么需要 API 令牌？</b></summary>

WeReadBar 跟微信读书数据网关通信 —— 用的是官方 [微信读书 Claude Skill](https://github.com/Tencent/WeChatReading) 同一套 API。你提供 bearer token（格式 `wrk-xxxxxxxx`），app 就能读你的书架、阅读时长、当前在读。没 token 拉不到数据。

在 [weread.qq.com/r/weread-skills](https://weread.qq.com/r/weread-skills) 获取。
</details>

<details>
<summary><b>会费电或拖慢 Mac 吗？</b></summary>

不会。app 静默驻留在菜单栏，CPU <1%、RAM ~50 MB。每 30 分钟只在弹窗打开时刷新一次，关闭就停。
</details>

<details>
<summary><b>能干净卸载吗？</b></summary>

能。把 `/Applications` 里的 `WeReadBar.app` 拖到废纸篓。要清掉存的令牌：
```bash
defaults delete com.local.wereadbar WeReadBar.apiToken
```
</details>

<details>
<summary><b>热力图数据怎么来的？</b></summary>

微信读书 API 只返回短窗口的每日数据，不是整年。WeReadBar 用 13 次月度请求拼出一整年（~1 秒）。macOS 上完全在后台跑 —— 加载时显示骨架，加载完淡入真实热力图。
</details>

---

## 请我喝杯咖啡 ☕

如果 WeReadBar 帮到你了，欢迎请我喝杯咖啡：

| 支付宝 | 微信支付 |
|:---:|:---:|
| ![Alipay](docs/alipay.jpg) | ![WeChat Pay](docs/wechatpay.jpg) |

---

## 致谢

- **数据源**：[微信读书 (WeRead)](https://weread.qq.com/) —— 腾讯的读书 app
- **API 网关**：[Tencent/WeChatReading](https://github.com/Tencent/WeChatReading) —— 官方 Claude Skill，本 app 构建于其上
- **技术栈**：Swift + SwiftUI，原生 AppKit 菜单栏集成
- **License**：MIT

---

<div align="center">

觉得有用的话，给个 ⭐ 帮别人发现它。

</div>
