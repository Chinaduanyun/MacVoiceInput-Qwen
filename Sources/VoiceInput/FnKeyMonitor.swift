import Foundation
import CoreGraphics
import Carbon

enum HotkeyType: String, CaseIterable {
    case fn
    case rightCommand
    case rightOption
    case rightControl

    var keyCode: Int64 {
        switch self {
        case .fn:           return 63
        case .rightCommand: return 54
        case .rightOption:  return 61
        case .rightControl: return 62
        }
    }

    var modifierFlag: CGEventFlags {
        switch self {
        case .fn:           return .maskSecondaryFn
        case .rightCommand: return .maskCommand
        case .rightOption:  return .maskAlternate
        case .rightControl: return .maskControl
        }
    }

    var displayName: String {
        switch self {
        case .fn:           return "Fn"
        case .rightCommand: return "Right ⌘"
        case .rightOption:  return "Right ⌥"
        case .rightControl: return "Right Ctrl"
        }
    }
}

protocol FnKeyMonitorDelegate: AnyObject {
    func fnKeyDidPress()
    func fnKeyDidRelease()
}

final class FnKeyMonitor {
    weak var delegate: FnKeyMonitorDelegate?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var runLoop: CFRunLoop?
    private var isKeyPressed = false
    private var monitorThread: Thread?
    var monitoredKey: HotkeyType

    init(hotkeyType: HotkeyType = .fn) {
        self.monitoredKey = hotkeyType
    }

    func startMonitoring() {
        print("[FnKeyMonitor] Starting monitoring for \(monitoredKey.displayName)...")
        monitorThread = Thread { [weak self] in
            self?.setupEventTap()
            self?.runLoop = CFRunLoopGetCurrent()
            CFRunLoopRun()
        }
        monitorThread?.name = "FnKeyMonitor"
        monitorThread?.start()
        print("[FnKeyMonitor] Monitoring thread started")
    }

    private func setupEventTap() {
        print("[FnKeyMonitor] Setting up event tap...")
        let eventMask = (1 << CGEventType.flagsChanged.rawValue)

        let callback: CGEventTapCallBack = { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }

            let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
            return monitor.handleEvent(proxy: proxy, type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("[FnKeyMonitor] ERROR: Failed to create event tap. Please grant Accessibility permissions in System Settings!")
            return
        }

        print("[FnKeyMonitor] Event tap created successfully")
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource!, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[FnKeyMonitor] Event tap enabled. Ready to detect \(monitoredKey.displayName) key.")
    }

    func stopMonitoring() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource, let rl = runLoop {
            CFRunLoopRemoveSource(rl, source, .commonModes)
            CFRunLoopStop(rl)
        }
        monitorThread = nil
        eventTap = nil
        runLoopSource = nil
        runLoop = nil
        isKeyPressed = false
    }

    func updateMonitoredKey(_ newKey: HotkeyType) {
        stopMonitoring()
        monitoredKey = newKey
        startMonitoring()
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .flagsChanged else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == monitoredKey.keyCode else {
            return Unmanaged.passUnretained(event)
        }

        let flags = event.flags
        let isDown = flags.contains(monitoredKey.modifierFlag)

        if isDown && !isKeyPressed {
            isKeyPressed = true
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.fnKeyDidPress()
            }
            return nil
        } else if !isDown && isKeyPressed {
            isKeyPressed = false
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.fnKeyDidRelease()
            }
            return nil
        }

        return Unmanaged.passUnretained(event)
    }
}
