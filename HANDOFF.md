# ClipboardCleaner — 交接文档 / HANDOFF

> 最后更新：2026-10-03（全部 10 个 slice 完成后，进入"实测反馈修复"阶段）
> 相关文档：`README.md`（构建命令、隐私声明 spec §43、非目标）
> ⚠️ 原始 50 节中文需求 spec **未入库**（仅存在于会话记录中）。代码注释里的 `§n` 引用、README 与本文档 §4 共同构成需求快照；如需回查原始 spec，向项目所有者索取。

---

## 0. 一分钟概览 / TL;DR

**EN:** A native macOS menu-bar utility (Swift + SwiftUI/AppKit, zero third-party deps): copy with ⌘C anywhere, press ⌘K (default, configurable in Settings) to paste a *cleaned* version into the frontmost app, then the original clipboard content is automatically restored. HTML is parsed locally by a hand-written tokenizer (regex tag-stripping is forbidden by the spec); structure (paragraphs, lists, indentation, code blocks, blockquotes) is preserved. Fully local: no network, no clipboard history, no analytics/telemetry/AI. All 10 slices are committed on `main`; 90 tests / 13 suites green; Debug + Release build OK; one full E2E paste round-trip verified in TextEdit.

- 菜单栏工具：任意 App 中 ⌘C 复制 → ⌘K（默认，可在设置里改）→ 把"干净版本"粘贴到当前 App → **自动恢复剪贴板原文**（再按 ⌘V 拿回原内容）。
- ⌥⌘V 曾是默认，但实测会把按键泄漏给前台 App（TextEdit/Notes 闪 Format 菜单、出十字光标）；换 ⌘K 后一切正常，用户拍板改为 ⌘K 默认。
- 清洗路径：HTML → 手写词法分析 + 块级转换器 → 结构化纯文本；RTF → 提取纯文本；纯文本 → 按模式处理。
- 清洗模式：`Plain Text`（直通）/ `Normalize`（折叠空白但保留结构）。
- 全程本地；粘贴内容永不写日志；无网络、无历史、无遥测。

### 当前状态快照 / Status snapshot

| 项 | 状态 |
|---|---|
| 功能实现（10 slices） | ✅ 全部提交（见 `git log`） |
| 单元 + 性能测试 | ✅ 90 tests / 13 suites 通过 |
| Debug / Release 构建 | ✅ 通过 |
| 实机 E2E（TextEdit 往返 + 剪贴板恢复） | ✅ 早期构建验证过 |
| 模式切换 UI 不刷新 Bug | ✅ 已修复并提交 `e1c5334`（**需在 Xcode 重新 Run 后生效**） |
| 辅助功能授权（⚠️ 问题） | ⏳ 根因已锁定，等用户重加授权条目后验证（§6.1） |
| 工程文件清理（profraw/README 出包） | ⏳ 等用户关闭 Xcode 后执行（§6.2） |
| 稳定签名决策 | ❓ 待"重新构建后授权是否失效"实验结果（§6.1） |
| 工作区 | `git status` 仅 `M ClipboardCleaner.xcodeproj/project.pbxproj`（用户 Xcode 重写过，勿直接回滚，见 §6.2） |

---

## 1. 构建与测试 / Build & Test

**EN:** Use `xcodebuild` with a temp `-derivedDataPath`. The test target for `-only-testing` is `ClipboardCleanerTests` (using `ClipboardCleaner` errors with "isn't a member of the scheme"). Suites use swift-testing (`@Suite` / `@Test` / `#expect`).

```bash
DD=/private/var/folders/mz/tlwrbp3n7f14y9pv8rjkzjk00000gn/T/opencode/dd
PROJ=ClipboardCleaner.xcodeproj

xcodebuild -project $PROJ -scheme ClipboardCleaner -derivedDataPath "$DD" test          # 全量测试
xcodebuild -project $PROJ -scheme ClipboardCleaner -derivedDataPath "$DD" build          # Debug 构建
xcodebuild -project $PROJ -scheme ClipboardCleaner -derivedDataPath "$DD" build -configuration Release
# 单测筛选（target 名是 ClipboardCleanerTests，不是 ClipboardCleaner）：
xcodebuild -project $PROJ -scheme ClipboardCleaner -derivedDataPath "$DD" test \
  -only-testing:ClipboardCleanerTests/CleaningModeObservationTests
```

- **13 个测试套件**：AppLanguage、CleaningMode、CleaningMode observation、CleaningEngine、HTMLCleaner、TextNormalizer、PlainTextCleaner、ClipboardReader、ClipboardWriter、HotkeyShortcut、GlobalHotkeyManager、PasteService、Performance。
- **性能基线**（PerformanceTests 守护）：64KB→16ms；1MB→237ms（>512KB 自动转后台）；病态嵌套结构耗时线性。
- 测试文件共 11 个：`ClipboardCleanerTests/*.swift`。`PasteServiceTests.successFlow` 偶发并行 flake（隔离跑必过），全绿基线以 `Test run with 90 tests in 13 suites passed` 为准。

---

## 2. 架构地图 / Architecture

**EN:** Thin `AppDelegate` + SwiftUI `MenuBarExtra(.window)`. Single `@Observable AppState` on the main actor wires everything; the cleaning engine is pure and testable. Pipeline: Carbon hotkey → `PasteService.trigger()` → AX gate → read → clean → write → ⌘V → changeCount-guarded restore → outcome → HUD/flash/dialog.

```
ClipboardCleaner/
├── App/
│   ├── ClipboardCleanerApp.swift   # MenuBarExtra(.window) + Settings scene；LSUIElement=true
│   ├── AppDelegate.swift           # 薄壳（spec 禁止巨型 AppDelegate）
│   └── AppState.swift              # @Observable 单例：接线、权限对话框、outcome→反馈映射
├── Clipboard/
│   ├── ClipboardReader.swift       # 多 flavour 读取；⚠️ 必须 UTF-16 flavour 优先解码（见 §5-2）
│   ├── ClipboardSnapshot.swift     # 读取结果模型 + changeCount
│   └── ClipboardWriter.swift       # captureRestorePoint / writeForPaste / changeCount 守卫的 restore
├── Cleaning/                       # 纯逻辑、无 AppKit 依赖，全部可单测
│   ├── CleaningEngine.swift        # 按 clipboard flavour 分发的清洗编排器
│   ├── HTMLCleaner.swift           # ⭐ 手写 HTML 词法分析 + 块级转换器（+ HTMLEntities）；spec 禁止正则剥标签
│   ├── RTFHandler.swift            # RTF → 纯文本
│   ├── PlainTextCleaner.swift      # ⚠️ CRLF 判断必须用 unicodeScalars（见 §5-1）
│   ├── TextNormalizer.swift        # 空白折叠/缩进保留（Normalize 模式核心）
│   └── CleaningOptions.swift       # 模式/选项定义
├── Hotkey/
│   ├── GlobalHotkeyManager.swift   # Carbon RegisterEventHotKey；回调内 MainActor.assumeIsolated
│   └── HotkeyShortcut.swift        # keycode+modifiers ↔ 显示串（默认 ⌘K）
├── Paste/
│   ├── PasteService.swift          # ⭐ 主管线：读→清洗→写→⌘V→恢复；背景阈值 512KB；PasteOutcome
│   └── AccessibilityService.swift  # AXIsProcessTrusted() + 打开系统设置 URL（不走 prompt API）
├── Settings/
│   ├── AppLanguage.swift           # 语言枚举（跟随系统/English/简体中文；改写 AppleLanguages）
│   └── AppPreferences.swift        # @Observable UserDefaults 封装（cleaningMode/appLanguage 为存储属性，见 §5-3）
└── UI/
    ├── MenuBarView.swift           # 面板（spec §29）：Paste Clean / 权限状态行 / 模式菜单 / 设置 / 退出
    ├── MenuBarIcon.swift           # 模板图标；⚠️ 闪 1.5s 自动恢复
    ├── FeedbackHUD.swift           # 瞬时反馈气泡（含 FeedbackWindowController）
    └── SettingsView.swift          # Launch at Login（SMAppService）/ 语言单选（改后自动重启）/ 快捷键录制器 / 默认模式 / 隐私文案
```

**主流程**：Carbon ⌘K → `AppState.pasteClean()` → `PasteService.trigger()`
→ AX 门禁（未授权 → `.permissionRequired`，**不碰剪贴板**）
→ `ClipboardReader` 快照（含 changeCount）→ `CleaningEngine`（按模式清洗）→ `ClipboardWriter.writeForPaste`（写净化结果）→ 合成 ⌘V → 按 changeCount 守卫恢复原文 → `onOutcome` → HUD / ⚠️ 闪 / 首次权限对话框。

---

## 3. 关键决策记录 / Key decisions

**EN:** macOS 14 minimum; hand-written Xcode project (objectVersion 77, file-system-synchronized groups); Carbon for the global hotkey; after the one-time permission dialog, feedback is menu-bar status + a 1.5 s icon flash only (never re-prompt); Normalize mode is intentionally NOT applied to HTML-derived output (would destroy nested-list / `pre` indentation) — this deviates from a literal reading of spec §17/18 and is documented in code; tests never touch `NSPasteboard.general`.

| 决策 | 选择 | 备注 |
|---|---|---|
| 最低系统 | macOS 14 Sonoma | 用户选定 |
| 工程文件 | 手写 `project.pbxproj`（objectVersion 77，`PBXFileSystemSynchronizedRootGroup`，原 ID `A100…`） | 新增源文件免改工程文件；但**用户的 Xcode 打开后已做过一次格式重写**（新 ID `BA1AF8…`），见 §6.2 |
| 全局热键 | Carbon `RegisterEventHotKey` | 用户选定；NSShortcut 全局监听不适用于 LSUIElement |
| 权限 UX | 首次弹一次解释对话框，之后仅"菜单状态行 + ⚠️ 闪 1.5s"，绝不重复弹窗 | 用户选定（spec §26–28） |
| "显示菜单栏图标"设置项 | **移除**（不提供） | 用户选定 |
| Normalize 与 HTML | **HTML 派生输出不套 Normalize** | 助理判断并已在代码/README 记录：会破坏嵌套列表与 `pre` 缩进；纯文本/RTF 路径严格按 spec §17/18 |
| 测试隔离 | 一律私有 `NSPasteboard(name:)`，**永不触碰 `.general`** | |
| 默认快捷键 | **⌘K**（`kVK_ANSI_K` + `.command`） | 原默认 ⌥⌘V 会把按键泄漏给前台 App（Format 菜单闪、十字光标）；换 ⌘K 后实测正常，用户拍板。用户机器已通过录制器存了 ⌘K，改动只影响新装与测试 |
| 语言设置 | 跟随系统（默认）/ English / 简体中文；写 per-app `AppleLanguages` 后**立即自动重启** | 用户选定；macOS 只在启动时解析界面语言，故必须重启；重启用 `sh -c "sleep 1; open -n …"` 避开双实例 |
| 启动方式 | `LSUIElement=true`（无 Dock 图标） | |
| 语言/依赖 | Swift 6 语言模式、纯系统框架、零第三方依赖 | spec 硬规则 |

---

## 4. 需求硬规则（不可违反）/ Hard rules

**EN:** No network/analytics/telemetry/AI, no clipboard history or polling; HTML must be parsed locally (hand-written, regex stripping forbidden); preserve structure; never log clipboard content; no force unwraps in app source; no giant AppDelegate; no third-party deps without justification; conventional commits on `main`; DoD = full functionality + tests, not just "build succeeds"; do not over-engineer.

1. 无网络 / 分析 / 遥测 / AI / 剪贴板历史上云；**无轮询**（仅事件驱动）。
2. HTML 本地解析，**正则剥标签被明确禁止**；保留段落、列表、缩进、代码块、`>` 引用。
3. **绝不把剪贴板内容写进日志**（日志只允许元信息：flavour、大小、耗时）。
4. App 源码无 force unwrap（测试代码可用）。
5. 不引入第三方依赖（除非给出充分理由并获用户同意）。
6. 每个切片一次 conventional commit，落在 `main`。
7. DoD = 功能完整 + 测试通过，而非"能编译就行"。
8. **不过度设计**（no gold-plating）。
9. MVP 明确不做（spec §47）：剪贴板历史、搜索、云、AI、OCR、翻译、Markdown 转换、持续监控、其他平台——**不要主动添加**。

---

## 5. 已修复的坑（勿回退）/ Fixed pitfalls — do NOT reintroduce

**EN:** Three real bugs were found and fixed; each has a test or code comment guarding it: (1) Swift treats `"\r\n"` as ONE grapheme, so `String.contains("\r")` misses CRLF — use `unicodeScalars`; (2) NSPasteboard synthesizes `public.utf8-plain-text` from UTF-16 data with the wrong byte order — decode UTF-16 flavours first; (3) `@Observable` does NOT track computed properties backed by UserDefaults — the cleaning mode must be a stored property (fix `e1c5334`, guarded by `CleaningModeObservationTests`).

1. **CRLF 图素坑**：Swift 把 `"\r\n"` 当作**一个** grapheme，`String.contains("\r")` 会漏掉 CRLF → `PlainTextCleaner` 用 `unicodeScalars.contains("\r")`。
2. **NSPasteboard 字节序坑**：剪贴板服务器会用**错误字节序**从 UTF-16 数据合成 `public.utf8-plain-text` → `ClipboardReader` 必须**先解码 UTF-16 flavour**，再回落其他。
3. **`@Observable` 不跟踪计算属性**（本次会话发现，`e1c5334` 修复）：`cleaningMode` 原是"计算属性读 UserDefaults"，视图注册不到依赖、切换模式 UI 不刷新（用户症状："菜单栏切换模式没有反应"，但 `defaults` 里其实存进去了）。现为**存储属性 + `didSet` 直写 UserDefaults**（`AppPreferences` 标了 `@Observable`），回归测试 `CleaningModeObservationTests`（先红后绿验证过）。

---

## 6. 未决事项 / Open items ⏳

### 6.1 辅助功能授权（⚠️ 问题）— 等用户重加条目后验证

**EN:** Diagnosis is complete: the app is ad-hoc signed (`Signature=adhoc`, CDHash changes on every build), yet the Accessibility list shows the entry ON while `AXIsProcessTrusted()` is false — a *fresh launch of the unchanged 19:54 build* was still untrusted, so the grant is bound to a different cdhash/path. User instructions were given (remove all entries → re-add via ⌘⇧G the exact DerivedData path → enable → report back). **Next agent:** verify when the user says done (snippet below), then run the rebuild experiment — if the next Xcode Run (which re-signs) loses trust again, present the signing options to the user (Apple Development cert via Xcode account / self-signed cert / re-grant each build) and let them choose. Do not decide unilaterally.

**证据链**：
- `codesign -dv`：`Signature=adhoc`、`TeamIdentifier=not set`、`CDHash=6b02ff26…`（每次构建必变）。
- 系统设置里"Clipboard Cleaner"条目**开关是开的**（用户确认），但原样重启 19:54 构建（零重新构建）后面板**仍显示** "Accessibility permission required" → 条目绑定的不是当前二进制（cdhash 或路径不匹配）。
- 用户首次按 ⌥⌘V 时对话框弹过、点了 Open Settings（已确认）→ `defaults` 里 `permissionPromptShown = 1`，按设计此后**永不重复弹窗**（只有状态行 + ⚠️ 闪 1.5s）。

**已给用户的操作指引**（等对方说"好了"）：
1. 辅助功能列表里所有 Clipboard Cleaner 条目全部删除；
2. `＋` → <kbd>⌘⇧G</kbd> 粘贴：
   `/Users/fiona/Library/Developer/Xcode/DerivedData/ClipboardCleaner-dajgmxwbldcibucivgjmviosnnii/Build/Products/Debug/ClipboardCleaner.app`
3. 打开开关。

**验证片段**（受信任面板 = 6 个顶层元素、无权限文案；未信任 = 8 个、含 "Accessibility permission required"）：

```applescript
tell application "System Events"
    tell process "ClipboardCleaner"
        click (first menu bar item of menu bar 2)
        delay 0.8
        set untrusted to false
        repeat with e in entire contents of first window
            try
                if (value of e as text) contains "Accessibility permission" then set untrusted to true
            end try
        end repeat
        click (first menu bar item of menu bar 2) -- 关回面板
        return untrusted -- false = 受信任 ✅
    end tell
end tell
```

**重建实验**（验证根因 §6.1 后半）：源码有改动 → 用户下次 Run 必然重新签名 → cdhash 变 → 观察授权是否再次失效。
- 失效 → 向用户摆选项（**必须问，不要自己定**）：① Xcode 账号 Apple Development 证书（Signing & Capabilities 选 Team，授权一次永久有效）；② 自签代码签名证书（可脚本化）；③ 接受每次重建后重新授权。
- 不失效 → 条目是路径级绑定，收工。

**当前 defaults 状态**（用户机器 `com.tinyfrictionkillers.ClipboardCleaner`）：`cleaningMode = normalize`、`permissionPromptShown = 1`、`hotkeyKeyCode/hotkeyModifiers` = ⌘K（录制器写入，与新默认一致）。想重新测首次对话框：`defaults delete com.tinyfrictionkillers.ClipboardCleaner permissionPromptShown`。

### 6.2 工程文件清理 — **等用户关闭 Xcode 后执行**（用户已选"你来清理并提交"）

**EN:** WAIT until the user confirms Xcode is quit — Xcode keeps the project in memory and would overwrite on-disk edits. Then: `git rm default.profraw` (a 0-byte artifact accidentally committed in `4501abe`), strip both `default.profraw` and `README.md` from the pbxproj (their PBXBuildFile, PBXFileReference, main-group children, and Copy-Bundle-Resources entries — keep Xcode's other normalization), verify with a test build, and commit.

背景：我的 `xcodebuild test` 在仓库根目录留下 0 字节 `default.profraw`，被 `4501abe` 误提交；用户的 Xcode 打开工程后又把它**和 `README.md`** 自动加进了 App 的 Copy Bundle Resources（会打进 .app）。`project.pbxproj` 当前为脏文件（Xcode 重写过，**保留其重写格式，只摘除这两组引用**）。

步骤（Xcode 已退出后）：
1. `git rm default.profraw`
2. 编辑 `ClipboardCleaner.xcodeproj/project.pbxproj`，删除 4 类条目（搜索 `default.profraw` 与 `README.md` 共 8 行）：
   - `PBXBuildFile` 段中两行 `… in Resources`；
   - `PBXFileReference` 段中两行；
   - 主 group `children` 中两行；
   - Resources build phase `files` 中两行。
   **其余全部保留**（`BA1AF8…` 新 ID、`PBXContainerItemProxy` 等是 Xcode 的正常规范化）。
3. `xcodebuild … build` 验证 + 全量 test。
4. 提交，例：`chore: drop build artifact and README from app resources`。
5. 提醒用户：下次用 Xcode 打开若又被自动加回（Xcode 曾自动收录根目录文件），重复步骤 2 即可。

### 6.3 尚未实机点过的 UI 路径（可选收尾）

**EN:** Not yet exercised live: shortcut recorder click-through, Launch at Login (SMAppService likely unhappy under ad-hoc signing from DerivedData — code already fails safe with toggle-off), visual confirmation that the ⚠️ flash reverts after 1.5 s. The one-time permission dialog itself WAS confirmed by the user.

- 快捷键录制器（Settings 窗口内点击 → 录制 → Escape 取消 → 冲突回落）：代码审阅过，未实机点过。
- Launch at Login（`SMAppService.mainApp`）：**未实测**。已知风险：ad-hoc 签名 + 从 DerivedData 运行时注册登录项很可能失败——代码已按"失败则开关弹回关闭"兜底；如需上线，应在 /Applications 安装路径下用稳定签名验证。
- ⚠️ 闪 1.5s 自动恢复：代码逻辑正确（`flashTask` 防重入），未做肉眼确认。
- 首次权限对话框：**用户已实机确认弹出过** ✅。

### 6.4 spec §47 排除项提醒

见 §4-9。交接后"顺手加功能"之前先对照这份排除清单。

---

## 7. 现场环境与调试手法 / Environment & debugging

**EN:** The user runs the app from Xcode (their DerivedData path below). The agent's shell is AX-trusted (inherits trust), so live UI automation works: `System Events` can click the status item / open the panel / drive the mode submenu; `defaults read com.tinyfrictionkillers.ClipboardCleaner` shows persisted state; AX element counts distinguish trusted/untrusted (snippet in §6.1). Helper scripts live in the opencode temp dir and may be purged — the techniques above are the durable part.

- 用户从 **Xcode** 运行（其 DerivedData）：
  `/Users/fiona/Library/Developer/Xcode/DerivedData/ClipboardCleaner-dajgmxwbldcibucivgjmviosnnii/`
- Agent 侧构建/测试目录：`/private/var/folders/mz/tlwrbp3n7f14y9pv8rjkzjk00000gn/T/opencode/dd`（临时目录，可能被系统清理，`xcodebuild` 会重建）。
- 同目录下曾有实测脚本（可能已被清理，思路可复用）：`ax_probe.swift` / `ax_probe2.swift`（AXUIElement 直读面板/子菜单/勾选）、`e2e_*.swift` / `e2e_*.applescript`（TextEdit 端到端）。
- **本环境 shell 进程 AX 受信任**（继承），所以可以直接用 `osascript`/System Events 驱动 UI：点状态栏图标开面板、开 Cleaning Mode 子菜单、点模式项——本会话已用此法证明"点击其实生效、只是 UI 不刷新"。
- 面板在脚本之间会自动关闭；子菜单点击后窗口可能存续——**动作和读取尽量放同一次脚本**。
- 读持久化状态：`defaults read com.tinyfrictionkillers.ClipboardCleaner`。
- macOS 26 SDK 怪癖：本项目用的 `fixedSize(horizontal:height:)` 在该 SDK 上签名是 `vertical:` 标签（已按现状编译通过）。
- `GlobalHotkeyManager` 里 `InstallEventHandler(GetApplicationEventTarget(), …)` 依赖宏展开；回调线程用 `MainActor.assumeIsolated` 回主队列——改动热键代码时保持这个结构。

---

## 8. 约定 / Conventions

**EN:** Conventional commits on `main` (`feat:`/`fix:`/`test:`/`docs:`/`chore:`). Code and comments in English; tests in swift-testing style; clipboard tests only on private pasteboards; no clipboard content in logs; no polling; no force unwraps in app source.

- 提交风格（`main`，共 11 条含本文档）：`feat:` × 7、`chore:` × 1、`docs`/`test:` × 2、`fix:` × 1，例：
  `fix: refresh views when cleaning mode changes`、`feat: add menu bar UI with permission status and mode menu`。
- 代码与注释：**英文**；测试用 swift-testing（`@Suite`/`@Test`/`#expect`/`confirmation`）。
- 剪贴板测试只用 `NSPasteboard(name:)` 私有板；日志只记元信息；App 源码无 `!`；无轮询。
- UI 文案即 spec 承诺（如 "Paste Clean"、"Accessibility permission required"），改动文案前回查 spec。

---

## 9. 建议下一步 / Suggested next steps

**EN:** (1) User re-adds the Accessibility entry → verify trust with the §6.1 snippet → E2E paste. (2) User quits Xcode → run the §6.2 cleanup → commit. (3) Rebuild (Xcode Run) → re-check trust → if lost, present signing options to the user. (4) Optionally live-check §6.3 UI paths. (5) Then the project meets spec DoD; anything beyond §4-9 exclusions needs the owner's explicit go-ahead.

1. 用户完成授权重加（§6.1）→ 用片段验证受信任 → 跑一次真实 ⌘K 往返。
2. 用户关闭 Xcode（§6.2）→ 清理工程文件与 `default.profraw` → 提交。
3. 源码已有改动（`e1c5334`），用户下次 Run 会重新签名 → 复验授权；失效则把签名方案选项**摆给用户选**。
4. 可选：实机补测 §6.3 各项。
5. 以上完成后项目即达 spec DoD；任何 §4 排除项/新需求先征询项目所有者。
