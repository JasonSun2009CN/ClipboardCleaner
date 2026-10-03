import Foundation

/// Cleaning behaviour selected by the user.
///
/// - `plainText`: remove rich formatting only. Preserve whitespace,
///   lists, indentation; only normalize line endings (CRLF/CR → LF).
/// - `normalize`: additionally collapse space runs, collapse repeated
///   blank lines to a maximum of one, and trim trailing whitespace.
enum CleaningMode: String, CaseIterable, Sendable {
    case plainText = "plainText"
    case normalize = "normalize"

    var displayName: String {
        switch self {
        case .plainText: "Plain Text"
        case .normalize: "Normalize"
        }
    }
}
