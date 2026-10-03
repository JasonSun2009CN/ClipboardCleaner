import AppKit
import SwiftUI

/// Menu bar template image: a clipboard with a small eraser mark.
/// Falls back to the plain clipboard symbol if `eraser` is unavailable.
struct MenuBarIcon: View {
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: "doc.on.clipboard")
            if NSImage(systemSymbolName: "eraser", accessibilityDescription: nil) != nil {
                Image(systemName: "eraser")
                    .font(.system(size: 8, weight: .bold))
                    .padding(1)
                    .background(Color.clear)
                    .offset(x: 3, y: 3)
            }
        }
        .font(.system(size: 14))
        .accessibilityLabel("Clipboard Cleaner")
    }
}
