import Foundation
import AVFoundation

/// Main coordinator that manages all components
class VoiceInputCoordinator: ObservableObject {
    static let shared = VoiceInputCoordinator()

    private var audioRecorder: AudioRecorder?
    private var webSocketManager: WebSocketManager?
    private var fnKeyMonitor: FnKeyMonitor?
    private var textInjector: TextInjector?
    private var floatingPanelController: FloatingWavePanelController?

    private var isRecording = false

    private init() {
        NSLog("[Coordinator] Initializing...")
    }

    func setupComponents() {
        NSLog("[Coordinator] Creating AudioRecorder...")
        audioRecorder = AudioRecorder()
        NSLog("[Coordinator] Creating WebSocketManager...")
        webSocketManager = WebSocketManager()
        NSLog("[Coordinator] Creating FnKeyMonitor...")
        fnKeyMonitor = FnKeyMonitor()
        NSLog("[Coordinator] Creating TextInjector...")
        textInjector = TextInjector()
        NSLog("[Coordinator] Creating FloatingPanelController...")
        floatingPanelController = FloatingWavePanelController()

        audioRecorder?.delegate = self
        webSocketManager?.delegate = self
        fnKeyMonitor?.delegate = self

        NSLog("[Coordinator] Starting FnKeyMonitor...")
        fnKeyMonitor?.startMonitoring()
        NSLog("[Coordinator] FnKeyMonitor started")
    }

    func startRecording() {
        guard !isRecording else { return }
        isRecording = true

        AppStateManager.shared.currentState = .recording
        AppStateManager.shared.resetTranscript()

        NotificationCenter.default.post(
            name: NSNotification.Name("VoiceInputStateChanged"),
            object: nil,
            userInfo: ["isRecording": true]
        )

        floatingPanelController?.show()

        let language = AppStateManager.shared.selectedLanguage
        webSocketManager?.connect(language: language)
    }

    func stopRecording() {
        guard isRecording else { return }
        audioRecorder?.stopRecording()
        webSocketManager?.commitAudioBuffer()
        AppStateManager.shared.currentState = .processing
    }

    func cancelRecording() {
        isRecording = false
        AppStateManager.shared.currentState = .idle

        NotificationCenter.default.post(
            name: NSNotification.Name("VoiceInputStateChanged"),
            object: nil,
            userInfo: ["isRecording": false]
        )

        audioRecorder?.stopRecording()
        webSocketManager?.disconnect()
        floatingPanelController?.hide()
    }

    func cleanup() {
        fnKeyMonitor?.stopMonitoring()
        audioRecorder?.stopRecording()
        webSocketManager?.disconnect()
    }

    func injectTranscript(_ text: String) {
        isRecording = false
        AppStateManager.shared.currentState = .idle

        NotificationCenter.default.post(
            name: NSNotification.Name("VoiceInputStateChanged"),
            object: nil,
            userInfo: ["isRecording": false]
        )

        floatingPanelController?.hide()

        if !text.isEmpty {
            textInjector?.injectText(text)
        }

        AppStateManager.shared.resetTranscript()
    }
}

extension VoiceInputCoordinator: AudioRecorderDelegate {
    func audioRecorder(_ recorder: AudioRecorder, didReceiveAudio pcm16Data: Data, rms: Float) {
        AppStateManager.shared.currentRMS = rms
        let base64Audio = pcm16Data.base64EncodedString()
        webSocketManager?.sendAudioChunk(base64Audio)
    }
}

extension VoiceInputCoordinator: WebSocketManagerDelegate {
    func webSocketManagerDidConnect(_ manager: WebSocketManager) {
        // Start recording audio once WebSocket is connected
        audioRecorder?.startRecording()
    }

    func webSocketManager(_ manager: WebSocketManager, didReceiveTranscriptDelta delta: String) {
        AppStateManager.shared.transcriptText += delta
        floatingPanelController?.updateWidth(for: AppStateManager.shared.transcriptText)
    }

    func webSocketManager(_ manager: WebSocketManager, didCompleteTranscript transcript: String) {
        injectTranscript(transcript)
    }

    func webSocketManager(_ manager: WebSocketManager, didEncounterError error: Error) {
        print("WebSocket error: \(error)")
        cancelRecording()
    }
}

extension VoiceInputCoordinator: FnKeyMonitorDelegate {
    func fnKeyDidPress() {
        startRecording()
    }

    func fnKeyDidRelease() {
        stopRecording()
    }
}