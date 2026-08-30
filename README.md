<div align="center">

# WeReadBar

**A tiny macOS menubar app that shows your 微信读书 (WeRead) reading stats at a glance.**

[📥 **Download**](../../releases/latest) · [⭐ Star](../../stargazers) · [🐛 Report a bug](../../issues)

</div>

---

## What is it?

WeReadBar lives in your menubar and shows:

- **A year-long heatmap** of when you read — like GitHub's contribution graph, but for books
- **Today's minutes**, **current streak**, **shelf total** — three numbers, one glance
- **Weekly total** for the current Mon–Sun week
- **Currently reading** book when nothing else is happening

Click the book icon to see the popover. Right-click for menu (Refresh / Go to Reading / Change API key / Quit). That's the whole app.

Built because opening weweread.qq.com in a browser just to check your streak is too many steps.

![Screenshot placeholder](docs/screenshot-popover.png)

---

## Features

- 📊 **Year-long heatmap** — every day of the last 53 weeks, color-coded by minutes read
- 🔥 **Streak counter** — current consecutive-day streak
- 📚 **Shelf total** — books + albums + 公众号 in your WeRead shelf
- ⏱ **Today's minutes** — how much you've read so far today
- 📅 **This week** — running Mon–Sun total
- 🌍 **三语支持 / Multilingual** — English, 简体中文, 繁體中文 (follows your system language)
- 🔐 **Keychain-stored** — your API token stays in macOS Keychain, never leaves your machine
- 🚫 **No Dock icon, no menu bar menu** — truly invisible until you need it

---

## Install

Requires **macOS 14 (Sonoma)** or later and a WeRead account.

1. **[Download the latest DMG](../../releases/latest)**
2. Open the DMG, drag **WeReadBar** to **/Applications**
3. **Right-click** `WeReadBar.app` in `/Applications` → **Open** → confirm
4. Paste your **WeRead API bearer token** when prompted (get one at [weread.qq.com/r/weread-skills](https://weread.qq.com/r/weread-skills))
5. Click the book icon in your menubar 🎉

> **Why the right-click step?** The app is signed without an Apple Developer ID, so macOS Gatekeeper asks you to confirm once. After that it opens normally.

---

## Privacy

- **Network**: WeReadBar only talks to `i.weread.qq.com` (WeRead's official API gateway). No analytics, no telemetry, no third-party services.
- **Credentials**: Your API token is stored in the macOS Keychain (entry `com.local.wereadbar.apikey`). It's never read by anything except this app.
- **Disk cache**: None. Every refresh re-fetches from WeRead.
- **Source**: Fully open. Read it, audit it, fork it.

---

## FAQ

<details>
<summary><b>Why does the API token matter?</b></summary>

WeReadBar talks to WeRead's data gateway the same way the official 微信读书 Claude Skill does — you provide a bearer token (the same format `wrk-xxxxxxxx`) and the app reads your shelf, reading time, and current book. Without a token, the app can't fetch your data.

Get one at [weread.qq.com/r/weread-skills](https://weread.qq.com/r/weread-skills).
</details>

<details>
<summary><b>Does this drain my battery or slow my Mac?</b></summary>

No. The app sits idle in your menubar consuming <1% CPU and ~50 MB RAM. It refreshes every 30 minutes only while the popover is open, and stops polling the moment you close it.
</details>

<details>
<summary><b>Can I uninstall it cleanly?</b></summary>

Yes. Drag `WeReadBar.app` from `/Applications` to the Trash. To wipe the stored token too:
```bash
security delete-generic-password -s "com.local.wereadbar.apikey"
```
</details>

<details>
<summary><b>How does the heatmap data get built?</b></summary>

The WeRead API only returns per-day data in narrow windows, not a full year. WeReadBar stitches 13 monthly fetches together (~1 second total) to fill the year-long grid. On macOS this all happens in the background — the app shows a skeleton while it loads, then cross-fades into the real heatmap.
</details>

<details>
<summary><b>Why is the icon a closed book?</b></summary>

It just felt right. SF Symbol `book.closed.fill`, auto-tinted to match your menubar's light/dark mode.
</details>

---

## Credits

- **Data**: [微信读书 (WeRead)](https://weread.qq.com/) — Tencent's reading app
- **API gateway**: [Tencent/WeChatReading](https://github.com/Tencent/WeChatReading) — the official Claude Skill this app is built on top of
- **Built with**: Swift + SwiftUI, native AppKit menubar integration
- **License**: MIT

---

<div align="center">

If you find WeReadBar useful, a ⭐ on GitHub helps others discover it.

</div>