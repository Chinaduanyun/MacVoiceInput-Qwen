import Cocoa
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var settingsWindow: NSWindow?
    var coordinator: VoiceInputCoordinator?
    private var stateObserver: NSObjectProtocol?

    override init() {
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "Voice Input")
        }

        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        statusItem.menu = menu

        NSApp.setActivationPolicy(.accessory)
        requestMicrophonePermission()

        coordinator = VoiceInputCoordinator.shared
        coordinator?.setupComponents()

        // Observe recording state to update menu bar icon color
        stateObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("VoiceInputStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let isRecording = notification.userInfo?["isRecording"] as? Bool ?? false
            self?.updateStatusIcon(recording: isRecording)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.cleanup()
    }

    func updateStatusIcon(recording: Bool) {
        guard let button = statusItem.button else { return }
        if recording {
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemOrange])
            button.image = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "Recording")?
                .withSymbolConfiguration(config)
        } else {
            button.image = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "Voice Input")
        }
    }

    private func requestMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow()
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}