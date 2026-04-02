import Cocoa
import SwiftUI

class SettingsWindow: NSWindow {
    private var viewModel: SettingsViewModel

    init() {
        viewModel = SettingsViewModel()

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        title = "Qwen-Omni Settings"
        center()
        isReleasedWhenClosed = false

        let hostingView = NSHostingView(rootView: SettingsView(viewModel: viewModel))
        contentView = hostingView
    }
}

class SettingsViewModel: ObservableObject {
    @Published var apiKey: String = ""
    @Published var model: String = ""
    @Published var selectedHotkey: HotkeyType = .fn
    @Published var statusMessage: String = ""
    @Published var statusColor: NSColor = .secondaryLabelColor

    init() {
        loadSettings()
    }

    func loadSettings() {
        apiKey = UserDefaults.standard.string(forKey: "dashscopeApiKey") ?? ""
        model = UserDefaults.standard.string(forKey: "modelName") ?? "qwen3.5-omni-plus-realtime"
        selectedHotkey = AppStateManager.shared.selectedHotkey
    }

    func saveSettings() {
        UserDefaults.standard.set(apiKey, forKey: "dashscopeApiKey")
        UserDefaults.standard.set(model, forKey: "modelName")
        AppStateManager.shared.setHotkey(selectedHotkey)

        statusMessage = "Settings saved successfully!"
        statusColor = .systemGreen

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.statusMessage = ""
        }
    }

    func testConnection() {
        guard !apiKey.isEmpty else {
            statusMessage = "Error: API Key is required"
            statusColor = .systemRed
            return
        }

        statusMessage = "Testing connection..."
        statusColor = .secondaryLabelColor

        let testModel = model.isEmpty ? "qwen3.5-omni-plus-realtime" : model
        let urlString = "wss://dashscope.aliyuncs.com/api-ws/v1/realtime?model=\(testModel)"
        guard let url = URL(string: urlString) else {
            statusMessage = "Error: Invalid URL"
            statusColor = .systemRed
            return
        }

        let session = URLSession(configuration: .default)
        var request = URLRequest(url: url)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")

        let webSocketTask = session.webSocketTask(with: request)

        // Try to receive one message to confirm the connection opened
        webSocketTask.receive { [weak self] result in
            DispatchQueue.main.async {
                webSocketTask.cancel(with: .normalClosure, reason: nil)
                switch result {
                case .success:
                    self?.statusMessage = "Connection successful!"
                    self?.statusColor = .systemGreen
                case .failure(let error):
                    let msg = error.localizedDescription
                    self?.statusMessage = "Connection failed: \(msg)"
                    self?.statusColor = .systemRed
                }
            }
        }
        webSocketTask.resume()
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(spacing: 20) {
            // API Key section
            VStack(alignment: .leading, spacing: 8) {
                Text("DashScope API Key:")
                    .font(.system(size: 13, weight: .medium))
                SecureField("Enter your DashScope API Key", text: $viewModel.apiKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(height: 24)
            }

            // Model section
            VStack(alignment: .leading, spacing: 8) {
                Text("Model:")
                    .font(.system(size: 13, weight: .medium))
                TextField("qwen3.5-omni-plus-realtime", text: $viewModel.model)
                    .textFieldStyle(.roundedBorder)
                    .frame(height: 24)
            }

            // Trigger Key section
            VStack(alignment: .leading, spacing: 8) {
                Text("Trigger Key:")
                    .font(.system(size: 13, weight: .medium))
                Picker("", selection: $viewModel.selectedHotkey) {
                    ForEach(HotkeyType.allCases, id: \.self) { key in
                        Text(key.displayName).tag(key)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            // Buttons
            HStack(spacing: 12) {
                Button("Test") {
                    viewModel.testConnection()
                }
                .frame(width: 80)

                Button("Save") {
                    viewModel.saveSettings()
                }
                .frame(width: 80)
                .keyboardShortcut(.defaultAction)
            }

            // Status label
            Text(viewModel.statusMessage)
                .font(.system(size: 12))
                .foregroundColor(Color(viewModel.statusColor))

            Spacer()
        }
        .padding(20)
    }
}