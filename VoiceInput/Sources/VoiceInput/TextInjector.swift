import Cocoa
import Carbon

final class TextInjector {

    func injectText(_ text: String) {
        // Save original clipboard
        let pasteboard = NSPasteboard.general
        let originalContents = pasteboard.string(forType: .string)

        // Check current input source
        let currentInputSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        var needsInputSwitch = false

        if let lang = getCurrentInputLanguage(), isCJKLanguage(lang) {
            needsInputSwitch = true
            switchToASCIICapableInput()
        }

        // Set text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Simulate Cmd+V after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.simulateCmdV()

            // Restore original state after paste
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // Restore clipboard
                pasteboard.clearContents()
                if let original = originalContents {
                    pasteboard.setString(original, forType: .string)
                }

                // Restore input source
                if needsInputSwitch {
                    TISSelectInputSource(currentInputSource)
                }
            }
        }
    }

    private func getCurrentInputLanguage() -> String? {
        let inputSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        guard let langPtr = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceLanguages) else {
            return nil
        }
        let langs = Unmanaged<CFArray>.fromOpaque(langPtr).takeUnretainedValue() as! [String]
        return langs.first
    }

    private func isCJKLanguage(_ lang: String) -> Bool {
        return lang.hasPrefix("zh") || lang.hasPrefix("ja") || lang.hasPrefix("ko")
    }

    private func switchToASCIICapableInput() {
        guard let asciiInput = findASCIICapableInput() else { return }
        TISSelectInputSource(asciiInput)
    }

    private func findASCIICapableInput() -> TISInputSource? {
        guard let inputSourceList = TISCreateInputSourceList(nil, false).takeRetainedValue() as? [TISInputSource] else {
            return nil
        }

        for inputSource in inputSourceList {
            guard let isASCIIPtr = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsASCIICapable) else {
                continue
            }
            let isASCIICapable = Unmanaged<CFBoolean>.fromOpaque(isASCIIPtr).takeUnretainedValue() == kCFBooleanTrue

            if isASCIICapable {
                return inputSource
            }
        }

        return nil
    }

    private func simulateCmdV() {
        let source = CGEventSource(stateID: .combinedSessionState)

        // Create Cmd+V key down event
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(0x09), keyDown: true)
        cmdDown?.flags = .maskCommand
        cmdDown?.post(tap: .cgAnnotatedSessionEventTap)

        // Create Cmd+V key up event
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(0x09), keyDown: false)
        cmdUp?.flags = .maskCommand
        cmdUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
}