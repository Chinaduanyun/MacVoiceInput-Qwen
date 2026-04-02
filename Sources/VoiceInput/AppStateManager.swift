import Foundation
import Combine

enum AppState {
    case idle
    case recording
    case processing
}

class AppStateManager: ObservableObject {
    static let shared = AppStateManager()

    @Published var currentState: AppState = .idle
    @Published var selectedLanguage: Language = .simplifiedChinese
    @Published var transcriptText: String = ""
    @Published var currentRMS: Float = 0
    @Published var selectedHotkey: HotkeyType = .fn

    private init() {
        loadLanguagePreference()
        loadHotkeyPreference()
    }

    private func loadLanguagePreference() {
        if let savedCode = UserDefaults.standard.string(forKey: "selectedLanguage"),
           let lang = Language.allCases.first(where: { $0.code == savedCode }) {
            selectedLanguage = lang
        }
    }

    private func loadHotkeyPreference() {
        if let savedRaw = UserDefaults.standard.string(forKey: "selectedHotkey"),
           let hotkey = HotkeyType(rawValue: savedRaw) {
            selectedHotkey = hotkey
        }
    }

    func setLanguage(_ language: Language) {
        selectedLanguage = language
        UserDefaults.standard.set(language.code, forKey: "selectedLanguage")
    }

    func setHotkey(_ hotkey: HotkeyType) {
        selectedHotkey = hotkey
        UserDefaults.standard.set(hotkey.rawValue, forKey: "selectedHotkey")
        NotificationCenter.default.post(name: NSNotification.Name("HotkeyChanged"), object: nil)
    }

    func resetTranscript() {
        transcriptText = ""
    }
}