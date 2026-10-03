import SwiftUI

/// The panel shown when the menu bar icon is clicked (spec §29).
struct MenuBarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Clipboard Cleaner")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

            Button {
                appState.pasteClean()
            } label: {
                MenuBarRow {
                    Text("Paste Clean")
                    Spacer()
                    Text(appState.shortcut.displayString)
                        .foregroundStyle(.secondary)
                        .monospaced()
                }
            }
            .buttonStyle(.plain)

            if !appState.isAccessibilityTrusted {
                MenuBarRow {
                    Text("Accessibility permission required")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Button {
                    appState.openAccessibilitySettings()
                } label: {
                    MenuBarRow {
                        Text("Open Settings")
                    }
                }
                .buttonStyle(.plain)
            }

            Menu {
                ForEach(CleaningMode.allCases, id: \.self) { mode in
                    Button {
                        appState.cleaningMode = mode
                    } label: {
                        if appState.cleaningMode == mode {
                            Label(mode.displayName, systemImage: "checkmark")
                        } else {
                            Text(mode.displayName)
                        }
                    }
                }
            } label: {
                MenuBarRow {
                    Text("Cleaning Mode")
                    Spacer()
                    Text(appState.cleaningMode.displayName)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
                .padding(.vertical, 6)

            SettingsLink {
                MenuBarRow {
                    Text("Settings...")
                }
            }

            Button {
                appState.quit()
            } label: {
                MenuBarRow {
                    Text("Quit Clipboard Cleaner")
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 10)
        }
        .frame(width: 280)
    }
}

/// One row in the menu bar panel.
private struct MenuBarRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 8) {
            content
        }
        .font(.body)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
