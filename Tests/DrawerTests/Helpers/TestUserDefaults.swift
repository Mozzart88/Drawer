import Foundation

func makeIsolatedDefaults() -> UserDefaults {
    let suite = UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    return defaults
}
