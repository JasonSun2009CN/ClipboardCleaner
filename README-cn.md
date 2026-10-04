# Clipboard Cleaner

[English](README.md) | 简体中文

一个轻量的原生 macOS 小工具，把富文本或杂乱的剪贴板内容变成干净的
纯文本，并直接粘贴到当前输入框。

```
正常复制
    ↓
⌘C
    ↓
⌘K
    ↓
清理剪贴板
    ↓
粘贴到当前光标位置
```

没有主窗口。不保存剪贴板历史。理想的体验是：你永远不需要想起这个
App——只会得到一次更好的粘贴。

## 它做什么

- 在你按下 ⌘K 的那一刻读取剪贴板（不监控、不存储）。
- 优先使用 HTML，其次是 RTF，再次是纯文本，因此结构得以保留：
  段落、换行、列表、缩进、代码块和引用标记都会保留；样式、链接
  地址以及没有替代文本的图片会被丢弃。
- 把清理后的文本粘贴到你正在使用的 App 中，然后把你的原始剪贴板
  原封不动地还原。
- 系统自带的 ⌘V 完全不受影响——macOS 的常规粘贴行为保持不变。
- 设置窗口提供快捷键录制、清洁模式、登录时启动，以及界面语言
  （跟随系统 / English / 简体中文）；切换语言会自动重启应用以生效。

## 清洁模式

| 模式 | 行为 |
| --- | --- |
| **纯文本**（默认） | 只去除富文本格式。空白、缩进、列表原样保留；仅统一换行符（CRLF/CR → LF）。 |
| **规范化** | 在此基础上：合并连续空格/制表符、把连续空行压成一行、去除行尾空白。 |

由 HTML 得到的内容始终只做结构性清理；规范化只作用于纯文本和 RTF
来源，因此列表缩进和代码块永远不会被破坏。

## 系统要求

- macOS 14 Sonoma 或更高版本
- Xcode 16+（用于构建）

## 构建与测试

```sh
xcodebuild -project ClipboardCleaner.xcodeproj -scheme ClipboardCleaner build
xcodebuild -project ClipboardCleaner.xcodeproj -scheme ClipboardCleaner test
```

这是一个菜单栏 App（`LSUIElement`）：没有 Dock 图标，启动时不打开
任何窗口。

## 权限

首次使用"清洁粘贴"时，macOS 会请求**辅助功能**权限——合成 ⌘V
按键事件是把清理后文本送进目标 App 的方式。Clipboard Cleaner 只在
第一次真正需要时询问一次，并提供直接跳转到"系统设置 → 隐私与安全
→ 辅助功能"的入口。如果你拒绝，一切照常：菜单栏会显示状态，且
App 绝不再打扰你。

## 隐私

Clipboard Cleaner 完全在本地运行。
你的剪贴板内容绝不离开这台 Mac。
App 不维护任何剪贴板历史。
不收集任何统计或遥测数据。

- 无账号、无网络请求、无云同步。
- 只在你触发"清洁粘贴"时读取剪贴板——没有剪贴板监控、没有轮询。
- 剪贴板内容绝不写入日志。
- HTML 在本地解析提取文本；不执行 JavaScript、不加载远程资源、
  不使用 WebView。

## v1 不做的事

剪贴板历史、搜索、云同步、AI、OCR、翻译、语法纠正、Markdown 转换、
剪贴板监控、遥测，以及非 macOS 平台——全部明确不在范围内。

## 项目结构

```
ClipboardCleaner/
├── App/        应用入口、委托、可观测的 App 状态
├── Clipboard/  快照、读取器、写入器（带还原）
├── Cleaning/   引擎、HTML 清理器、RTF 处理、规范化器
├── Paste/      粘贴流水线、辅助功能门禁
├── Hotkey/     全局快捷键（Carbon RegisterEventHotKey）
├── UI/         菜单栏面板、设置、反馈 HUD
├── Settings/   基于 UserDefaults 的偏好设置
└── Tests/      单元 + 模糊测试（Swift Testing）
```
