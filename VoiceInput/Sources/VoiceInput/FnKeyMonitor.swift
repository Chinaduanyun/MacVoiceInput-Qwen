import Foundation
import CoreGraphics
import Carbon

protocol FnKeyMonitorDelegate: AnyObject {
    func fnKeyDidPress()
    func fnKeyDidRelease()
}

final class FnKeyMonitor {
    weak var delegate: FnKeyMonitorDelegate?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isFnPressed = false
    private var monitorThread: Thread?

    func startMonitoring() {
        print("[FnKeyMonitor] Starting monitoring...")
        monitorThread = Thread { [weak self] in
            self?.setupEventTap()
            CFRunLoopRun()
        }
        monitorThread?.name = "FnKeyMonitor"
        monitorThread?.start()
        print("[FnKeyMonitor] Monitoring thread started")
    }

    private func setupEventTap() {
        print("[FnKeyMonitor] Setting up event tap...")
        let eventMask = (1 << CGEventType.keyDown.rawValue) |
                        (1 << CGEventType.keyUp.rawValue) |
                        (1 << CGEventType.flagsChanged.rawValue)

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
        print("[FnKeyMonitor] Event tap enabled. Ready to detect Fn key.")
    }

    func stopMonitoring() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        monitorThread = nil
        eventTap = nil
        runLoopSource = nil
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        if keyCode == 63 { // Fn key
            if type == .flagsChanged {
                // Check if Fn modifier flag is currently active
                let flags = event.flags
                let fnIsDown = flags.contains(.maskSecondaryFn)

                if fnIsDown && !isFnPressed {
                    isFnPressed = true
                    DispatchQueue.main.async { [weak self] in
                        self?.delegate?.fnKeyDidPress()
                    }
                    return nil // Suppress the event
                } else if !fnIsDown && isFnPressed {
                    isFnPressed = false
                    DispatchQueue.main.async { [weak self] in
                        self?.delegate?.fnKeyDidRelease()
                    }
                    return nil // Suppress the event
                }
            } else if type == .keyDown && !isFnPressed {
                isFnPressed = true
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.fnKeyDidPress()
                }
                return nil
            } else if type == .keyUp && isFnPressed {
                isFnPressed = false
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.fnKeyDidRelease()
                }
                return nil
            }
        }

        return Unmanaged.passUnretained(event)
    }
}