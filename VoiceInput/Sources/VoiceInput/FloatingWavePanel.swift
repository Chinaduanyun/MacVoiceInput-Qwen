import Cocoa
import SwiftUI
import AVFoundation

class FloatingWavePanelController: ObservableObject {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<FloatingWavePanelView>?

    private let panelHeight: CGFloat = 56
    private let minPanelWidth: CGFloat = 200
    private let maxPanelWidth: CGFloat = 800

    func show() {
        if panel == nil {
            createPanel()
        }

        guard let panel = panel else { return }

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let panelWidth = minPanelWidth
        let panelX = screenFrame.midX - panelWidth / 2
        let panelY = screenFrame.minY + 100

        panel.setFrame(NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight), display: false)
        panel.alphaValue = 0
        panel.orderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard let panel = panel else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
        }
    }

    func updateWidth(for text: String) {
        guard let panel = panel else { return }

        let textWidth = text.boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: 20),
            options: .usesLineFragmentOrigin,
            attributes: [.font: NSFont.systemFont(ofSize: 14)]
        ).width

        let newWidth = max(minPanelWidth, min(maxPanelWidth, textWidth + 100))
        let currentFrame = panel.frame
        let newX = currentFrame.midX - newWidth / 2

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(NSRect(x: newX, y: currentFrame.origin.y, width: newWidth, height: panelHeight), display: true)
        }
    }

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: minPanelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false

        let hostingView = NSHostingView(rootView: FloatingWavePanelView())
        hostingView.frame = NSRect(x: 0, y: 0, width: minPanelWidth, height: panelHeight)
        panel.contentView = hostingView

        self.hostingView = hostingView
        self.panel = panel
    }
}

struct FloatingWavePanelView: View {
    @ObservedObject var appState = AppStateManager.shared

    var body: some View {
        ZStack {
            // Background with visual effect
            VisualEffectBlurView()
                .cornerRadius(28)

            HStack(spacing: 16) {
                // Waveform animation
                WaveformBarsView(rms: appState.currentRMS)
                    .frame(width: 44, height: 32)

                // Transcript text
                Text(appState.transcriptText)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 16)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(height: 56)
    }
}

struct VisualEffectBlurView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        view.wantsLayer = true
        view.layer?.cornerRadius = 28
        view.layer?.masksToBounds = true
        view.layer?.backgroundColor = NSColor(white: 0.12, alpha: 0.92).cgColor
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct WaveformBarsView: View {
    let rms: Float
    private let barWeights: [CGFloat] = [0.5, 0.8, 1.0, 0.75, 0.55]

    @State private var animatedHeights: [CGFloat] = [4, 4, 4, 4, 4]
    @State private var smoothedRMS: Float = 0

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white)
                    .frame(width: 6, height: animatedHeights[i])
            }
        }
        .onReceive(Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()) { _ in
            updateBars()
        }
    }

    private func updateBars() {
        // Smooth RMS with attack/release
        let attack: Float = 0.4
        let release: Float = 0.15

        if rms > smoothedRMS {
            smoothedRMS = smoothedRMS * (1 - attack) + rms * attack
        } else {
            smoothedRMS = smoothedRMS * (1 - release) + rms * release
        }

        let normalizedRMS = min(1.0, smoothedRMS * 8.0) // Amplify for visibility
        let maxHeight: CGFloat = 32

        for i in 0..<5 {
            let weight = barWeights[i]
            let jitter = CGFloat.random(in: -0.04...0.04)
            let effectiveWeight = weight * (1.0 + jitter)
            let height = max(4, maxHeight * CGFloat(normalizedRMS) * effectiveWeight)
            animatedHeights[i] = height
        }
    }
}