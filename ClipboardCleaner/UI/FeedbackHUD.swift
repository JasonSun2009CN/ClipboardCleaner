import AppKit
import SwiftUI

/// Small non-activating HUD for transient messages such as
/// "Nothing to clean." — never takes keyboard focus, dismisses itself.
@MainActor
final class FeedbackWindowController {
    private var window: NSWindow?
    private var dismissTask: Task<Void, Never>?

    func show(_ message: String, duration: TimeInterval = 1.6) {
        dismissTask?.cancel()

        let hostingView = NSHostingView(rootView: FeedbackView(message: message))
        let panel = window ?? makeWindow()
        window = panel

        panel.setContentSize(hostingView.fittingSize)
        panel.contentView = hostingView
        position(panel)
        panel.orderFrontRegardless()

        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.window?.orderOut(nil)
        }
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 64),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return window
    }

    private func position(_ window: NSWindow) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let size = window.frame.size
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2
        )
        window.setFrameOrigin(origin)
    }
}

struct FeedbackView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.callout.weight(.medium))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
            .padding(12)
    }
}
