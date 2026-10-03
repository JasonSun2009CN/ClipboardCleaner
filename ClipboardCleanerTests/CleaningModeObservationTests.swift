import Foundation
import Testing
@testable import ClipboardCleaner

/// The panel and Settings picker display `cleaningMode`; if mutating it does
/// not notify Observation, views keep showing the old mode ("no reaction"
/// when switching, spec §29). Computed-over-UserDefaults properties are not
/// tracked by `@Observable`, so the mode must be a stored property.
@Suite("CleaningMode observation")
struct CleaningModeObservationTests {
    @Test("Mutating cleaningMode notifies observers")
    func modeChangeNotifiesObservers() async {
        let prefs = AppPreferences(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        #expect(prefs.cleaningMode == .plainText)

        await confirmation("observer notified exactly once") { notified in
            withObservationTracking {
                _ = prefs.cleaningMode
            } onChange: {
                notified()
            }
            prefs.cleaningMode = .normalize
            // Allow async delivery of the change notification.
            try? await Task.sleep(for: .milliseconds(100))
        }

        #expect(prefs.cleaningMode == .normalize)
    }

    @Test("Mode change still persists to UserDefaults")
    func persistsToDefaults() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let prefs = AppPreferences(defaults: defaults)
        prefs.cleaningMode = .normalize
        #expect(defaults.string(forKey: "cleaningMode") == CleaningMode.normalize.rawValue)
        #expect(AppPreferences(defaults: defaults).cleaningMode == .normalize)
    }
}
