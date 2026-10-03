import AppKit
import SwiftUI

/// Menu bar template image: a clipboard with a small eraser mark.
/// While permission feedback is flashing it becomes a warning mark
/// (spec §28: brief, non-intrusive feedback after a denial).
struct MenuBarIcon: View {
    var isFlashingPermission = false

    var body: some View {
        Group {
            if isFlashingPermission {
                Image(systemName: "exclamationmark.triangle")
            } else {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "doc.on.clipboard")
                    if NSImage(systemSymbolName: "eraser", accessibilityDescription: nil) != nil {
                        Image(systemName: "eraser")
                            .font(.system(size: 8, weight: .bold))
                            .offset(x: 3, y: 3)
                    }
                }
            }
        }
        .font(.system(size: 14))
        .accessibilityLabel("Clipboard Cleaner")
    }
}
