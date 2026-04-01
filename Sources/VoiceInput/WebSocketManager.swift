import Foundation

protocol WebSocketManagerDelegate: AnyObject {
    func webSocketManager(_ manager: WebSocketManager, didReceiveTranscriptDelta delta: String)
    func webSocketManager(_ manager: WebSocketManager, didCompleteTranscript transcript: String)
    func webSocketManager(_ manager: WebSocketManager, didEncounterError error: Error)
    func webSocketManagerDidConnect(_ manager: WebSocketManager)
}

final class WebSocketManager: NSObject, URLSessionWebSocketDelegate {
    weak var delegate: WebSocketManagerDelegate?

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?

    private var accumulatedTranscript = ""
    private var isConnected = false
    private var pendingAudioBuffer: [String] = []
    private var pendingLanguage: Language = .simplifiedChinese
    private var pendingModel: String = "qwen3.5-omni-plus-realtime"

    func connect(language: Language) {
        guard !isConnected else { return }
        print("[WebSocket] Connecting...")

        accumulatedTranscript = ""
        pendingLanguage = language

        let apiKey = UserDefaults.standard.string(forKey: "dashscopeApiKey") ?? ""
        let model = UserDefaults.standard.string(forKey: "modelName") ?? "qwen3.5-omni-plus-realtime"
        pendingModel = model

        print("[WebSocket] API Key: \(apiKey.isEmpty ? "NOT SET" : "configured (\(apiKey.count) chars)")")
        print("[WebSocket] Model: \(model)")

        if apiKey.isEmpty {
            print("[WebSocket] ERROR: No API Key configured! Please set it in Settings.")
            delegate?.webSocketManager(self, didEncounterError: NSError(domain: "No API Key configured", code: -1))
            return
        }

        // Correct DashScope Qwen-Omni-Realtime URL (not compatible-mode)
        let urlString = "wss://dashscope.aliyuncs.com/api-ws/v1/realtime?model=\(model)"
        guard let url = URL(string: urlString) else {
            print("[WebSocket] ERROR: Invalid URL")
            delegate?.webSocketManager(self, didEncounterError: NSError(domain: "Invalid URL", code: -1))
            return
        }

        print("[WebSocket] URL: \(urlString)")

        let configuration = URLSessionConfiguration.default
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)

        var request = URLRequest(url: url)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        webSocketTask = session?.webSocketTask(with: request)
        webSocketTask?.resume()
        print("[WebSocket] WebSocket task resumed, waiting for connection...")
    }

    func disconnect() {
        isConnected = false
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        session = nil
        pendingAudioBuffer.removeAll()
    }

    func sendAudioChunk(_ base64Audio: String) {
        guard isConnected else {
            pendingAudioBuffer.append(base64Audio)
            return
        }

        let message: [String: Any] = [
            "type": "input_audio_buffer.append",
            "audio": base64Audio
        ]
        sendJSONMessage(message)
    }

    func commitAudioBuffer() {
        guard isConnected else { return }
        let commitMessage: [String: Any] = ["type": "input_audio_buffer.commit"]
        sendJSONMessage(commitMessage)
        print("[WebSocket] Committed audio buffer")

        // Manual mode: explicitly request a response after commit
        let responseCreate: [String: Any] = ["type": "response.create"]
        sendJSONMessage(responseCreate)
        print("[WebSocket] Sent response.create")
    }

    private func sendSessionUpdate(language: Language, model: String) {
        // Manual mode: explicitly set turn_detection to null (NSNull → JSON null)
        let sessionMessage: [String: Any] = [
            "type": "session.update",
            "session": [
                "modalities": ["text"],
                "instructions": language.systemPrompt,
                "input_audio_format": "pcm",
                "turn_detection": NSNull()
            ]
        ]
        sendJSONMessage(sessionMessage)
        isConnected = true
        print("[WebSocket] Session update sent (manual mode, turn_detection=null)")
        delegate?.webSocketManagerDidConnect(self)

        // Send pending audio
        for audioChunk in pendingAudioBuffer {
            sendAudioChunk(audioChunk)
        }
        pendingAudioBuffer.removeAll()
    }

    private func sendJSONMessage(_ message: [String: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: message)
            guard let jsonString = String(data: data, encoding: .utf8) else {
                print("[WebSocket] Failed to convert JSON data to string")
                return
            }
            let wsMessage = URLSessionWebSocketTask.Message.string(jsonString)
            webSocketTask?.send(wsMessage) { error in
                if let error = error {
                    print("[WebSocket] Send error: \(error)")
                }
            }
        } catch {
            print("[WebSocket] JSON serialization error: \(error)")
        }
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.receiveMessage()

            case .failure(let error):
                self.delegate?.webSocketManager(self, didEncounterError: error)
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        var messageData: Data?

        switch message {
        case .data(let data):
            messageData = data
        case .string(let text):
            messageData = text.data(using: .utf8)
        @unknown default:
            break
        }

        guard let data = messageData else { return }

        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                handleEvent(json)
            }
        } catch {
            print("JSON parse error: \(error)")
        }
    }

    private func handleEvent(_ json: [String: Any]) {
        let eventType = json["type"] as? String ?? ""
        print("[WebSocket] Event: \(eventType)")

        switch eventType {
        case "session.created", "session.updated":
            print("[WebSocket] Session ready")

        case "response.audio_transcript.delta", "response.text.delta":
            if let delta = json["delta"] as? String {
                accumulatedTranscript += delta
                delegate?.webSocketManager(self, didReceiveTranscriptDelta: delta)
            }

        case "response.audio_transcript.done", "response.text.done":
            if !accumulatedTranscript.isEmpty {
                delegate?.webSocketManager(self, didCompleteTranscript: accumulatedTranscript)
                accumulatedTranscript = ""
            }

        case "response.done":
            if !accumulatedTranscript.isEmpty {
                delegate?.webSocketManager(self, didCompleteTranscript: accumulatedTranscript)
                accumulatedTranscript = ""
            }

        case "input_audio_buffer.committed", "input_audio_buffer.speech_started",
             "input_audio_buffer.speech_stopped", "conversation.item.created",
             "response.created", "response.output_item.added",
             "response.content_part.added", "response.audio.delta",
             "response.audio.done", "response.content_part.done",
             "response.output_item.done":
            break // expected events, no action needed

        case "error":
            let errorMsg: String
            if let errObj = json["error"] as? [String: Any] {
                let code = errObj["code"] as? String ?? ""
                let msg = errObj["message"] as? String ?? "unknown"
                errorMsg = "[\(code)] \(msg)"
            } else if let msg = json["error"] as? String {
                errorMsg = msg
            } else {
                errorMsg = "Unknown error: \(json)"
            }
            print("[WebSocket] SERVER ERROR: \(errorMsg)")
            delegate?.webSocketManager(self, didEncounterError: NSError(
                domain: "WebSocketServerError", code: -1,
                userInfo: [NSLocalizedDescriptionKey: errorMsg]
            ))

        default:
            print("[WebSocket] Unhandled event: \(eventType) — \(json)")
        }
    }

    // URLSessionWebSocketDelegate methods
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("[WebSocket] Connection opened, sending session update...")
        sendSessionUpdate(language: pendingLanguage, model: pendingModel)
        receiveMessage()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("[WebSocket] Connection closed with code: \(closeCode.rawValue)")
        isConnected = false
        if !accumulatedTranscript.isEmpty {
            delegate?.webSocketManager(self, didCompleteTranscript: accumulatedTranscript)
            accumulatedTranscript = ""
        }
    }

    // Catches handshake failures (e.g. HTTP 404 before WebSocket upgrade)
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error else { return }
        print("[WebSocket] Task failed: \(error.localizedDescription)")
        if !isConnected {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.webSocketManager(self, didEncounterError: error)
            }
        }
    }
}