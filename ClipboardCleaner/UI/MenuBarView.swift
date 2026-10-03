import SwiftUI

/// The popover shown when the menu bar icon is clicked.
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

            MenuBarRow {
                Text("Paste Clean")
                Spacer()
                Text("⌥⌘V")
                    .foregroundStyle(.secondary)
                    .monospaced()
            }
            .onTapGesture { appState.pasteClean() }

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
        .frame(width: 260)
    }
}

/// One tappable row in the menu bar panel.
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
