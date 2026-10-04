# Clipboard Cleaner

English | [简体中文](README-cn.md)

A lightweight native macOS utility that turns rich or messy clipboard
content into clean plain text and pastes it directly into the current
input field.

```
Copy normally
    ↓
⌘C
    ↓
⌘K
    ↓
Clean clipboard
    ↓
Paste at current cursor
```

No main window. No clipboard history. The ideal experience is that you
never think about the app — you just get a better Paste.

## What it does

- Reads the clipboard at the moment you press ⌘K (nothing is monitored
  or stored).
- Prefers HTML, then RTF, then plain text, so structure survives:
  paragraphs, line breaks, lists, indentation, code blocks, and
  blockquote markers are kept; styling, links-as-URLs, and images without
  alt text are dropped.
- Pastes the cleaned text into the app you are working in, then restores
  your original clipboard exactly as it was.
- Keeps the normal ⌘V untouched — system paste always behaves the way
  macOS does.

## Cleaning modes

| Mode | Behaviour |
| --- | --- |
| **Plain Text** (default) | Removes rich formatting, preserves whitespace and indentation, only unifies line endings. |
| **Normalize** | Additionally collapses space runs, collapses blank-line runs to one, and trims trailing whitespace. |

HTML-derived content is always cleaned structurally; Normalize applies to
plain-text and RTF sources so list indentation and code blocks are never
destroyed.

## Requirements

- macOS 14 Sonoma or later
- Xcode 16+ (to build)

## Build and test

```sh
xcodebuild -project ClipboardCleaner.xcodeproj -scheme ClipboardCleaner build
xcodebuild -project ClipboardCleaner.xcodeproj -scheme ClipboardCleaner test
```

The app is a menu bar app (`LSUIElement`): no Dock icon, no windows at
launch.

## Permissions

The first time you use Paste Clean, macOS asks for **Accessibility**
permission — a synthetic ⌘V keystroke is how the cleaned text gets into
the app you are working in. Clipboard Cleaner asks once, when you first
need it, and offers a direct jump to System Settings → Privacy &
Security → Accessibility. If you decline, nothing breaks: the menu bar
shows the status and the app never nags again.

## Privacy

Clipboard Cleaner is local-only.
Your clipboard contents never leave your Mac.
The app does not maintain clipboard history.
No analytics or telemetry are collected.

- No account, no network requests, no cloud sync.
- The clipboard is read only when you trigger Paste Clean — there is no
  clipboard monitoring or polling.
- Clipboard contents are never written to logs.
- HTML is parsed locally to extract text; no JavaScript runs, no remote
  resources load, no WebView is involved.

## Not in v1

Clipboard history, search, cloud sync, AI, OCR, translation, grammar
correction, Markdown conversion, clipboard monitoring, telemetry, and
non-macOS platforms are explicitly out of scope.

## Project layout

```
ClipboardCleaner/
├── App/        app entry, delegate, observable app state
├── Clipboard/  snapshot, reader, writer (with restore)
├── Cleaning/   engine, HTML cleaner, RTF handler, normalizers
├── Paste/      paste pipeline, accessibility gate
├── Hotkey/     global shortcut (Carbon RegisterEventHotKey)
├── UI/         menu bar panel, settings, feedback HUD
├── Settings/   UserDefaults-backed preferences
└── Tests/      unit + fuzz tests (Swift Testing)
```
