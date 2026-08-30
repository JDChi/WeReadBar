# CLAUDE.md

For full project guidance — architecture, key gotchas, file layout, smoke tests — see [AGENTS.md](./AGENTS.md). This file is just the Claude Code-specific pointer plus a few reminders.

**Current scale**: year-long GitHub-style heatmap, ~13-month data fetch, 600pt popover. Numeric constants live in `UI/HeatmapView.swift` and `Data/StatsStore.swift`; treat them as load-bearing for layout.

## Quick reminders for Claude

- **Use `os.Logger`** (subsystem `com.local.wereadbar`), not `print`. This is an `LSUIElement` app; `stdout` doesn't show up in the console.
- **Concurrency model**: `actor` for `WeReadClient`, `@MainActor` for `StatsStore`. Don't break isolation. Long loops should `Task.checkCancellation()`.
- **Headless compile check**: `xcodebuild -project WeReadBar.xcodeproj -scheme WeReadBar -configuration Debug -destination 'platform=macOS' CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build`
- **After editing `project.yml`**: re-run `xcodegen generate`.
- **API contract** (read [`AGENTS.md` §Key gotchas](./AGENTS.md#key-gotchas--do-not-fix-these) before changing the data layer): single gateway endpoint, Bearer auth, **all params flat in the JSON body**, every request must include `skill_version: "1.0.4"`.
- **Bearer token storage**: macOS preferences (UserDefaults key `WeReadBar.apiToken`, plist at `~/Library/Preferences/com.local.wereadbar.plist`). Never read from env vars — accessory apps have no shell environment.

## When stuck

- The plan file at `~/.claude/plans/noble-beaming-locket.md` has the original design notes.
- The installed skill at `~/.agents/skills/weread-skills/` documents the upstream WeRead API contract.
- Capture runtime logs with: `log stream --predicate 'subsystem == "com.local.wereadbar"' --info --debug`.
