import Carbon
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        Form {
            Section("General") {
                LaunchAtLoginToggle()
            }

            Section("Language") {
                Picker("App Language", selection: $appState.appLanguage) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: appState.appLanguage) { _, _ in
                    // The interface language is fixed at launch, so restart.
                    appState.relaunch()
                }
                Text("The app restarts to apply the new language.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Shortcut") {
                HStack {
                    Text("Paste Clean")
                    Spacer()
                    ShortcutRecorder()
                }
                if appState.isShortcutConflicted {
                    Text("This shortcut couldn't be registered. It may already be in use by another app.")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            }

            Section("Cleaning") {
                Picker("Default Mode", selection: $appState.cleaningMode) {
                    ForEach(CleaningMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Privacy") {
                Text("""
                Clipboard Cleaner works entirely on this Mac. \
                Clipboard contents are never uploaded or stored.
                """)
                .foregroundStyle(.secondary)
                .font(.callout)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Native login-item toggle via SMAppService. Failures keep the toggle
/// off rather than interrupting the user.
private struct LaunchAtLoginToggle: View {
    @State private var isEnabled = SMAppService.mainApp.status == .enabled

    var body: some View {
        Toggle("Launch at Login", isOn: $isEnabled)
            .onChange(of: isEnabled) { _, newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    isEnabled = SMAppService.mainApp.status == .enabled
                }
            }
    }
}

/// Records the next valid key combination and registers it as the
/// Paste Clean shortcut. A modifier is required so ordinary typing is
/// never swallowed, and Escape cancels recording.
private struct ShortcutRecorder: View {
    @Environment(AppState.self) private var appState
    @State private var isRecording = false
    @State private var monitor: Any?

    /// Keys that only modify other keys — pressing one alone is not a shortcut.
    private static let modifierKeyCodes: Set<UInt32> = [
        UInt32(kVK_Shift), UInt32(kVK_Control), UInt32(kVK_Option), UInt32(kVK_Command),
        UInt32(kVK_CapsLock), UInt32(kVK_Function),
        UInt32(kVK_RightShift), UInt32(kVK_RightControl),
        UInt32(kVK_RightOption), UInt32(kVK_RightCommand),
    ]

    var body: some View {
        Button {
            isRecording ? stop() : start()
        } label: {
            Text(isRecording ? String(localized: "Type shortcut…") : appState.shortcut.displayString)
                .monospaced()
                .frame(minWidth: 96)
        }
        .onDisappear { stop() }
    }

    private func start() {
        isRecording = true
        appState.isRecordingShortcut = true
        appState.setHotkeyPaused(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKey(event)
            return nil // always swallowed while recording
        }
    }

    private func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        isRecording = false
        appState.isRecordingShortcut = false
        appState.setHotkeyPaused(false)
    }

    private func handleKey(_ event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            stop()
            return
        }
        let keyCode = UInt32(event.keyCode)
        if Self.modifierKeyCodes.contains(keyCode) {
            return
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let shortcut = HotkeyShortcut(keyCode: keyCode, modifiers: flags)
        guard shortcut.hasModifier else {
            NSSound.beep()
            return
        }

        appState.updateShortcut(shortcut)
        stop()
    }
}
