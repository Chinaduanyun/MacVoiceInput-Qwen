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

    private init() {
        loadLanguagePreference()
    }

    private func loadLanguagePreference() {
        if let savedCode = UserDefaults.standard.string(forKey: "selectedLanguage"),
           let lang = Language.allCases.first(where: { $0.code == savedCode }) {
            selectedLanguage = lang
        }
    }

    func setLanguage(_ language: Language) {
        selectedLanguage = language
        UserDefaults.standard.set(language.code, forKey: "selectedLanguage")
    }

    func resetTranscript() {
        transcriptText = ""
    }
}