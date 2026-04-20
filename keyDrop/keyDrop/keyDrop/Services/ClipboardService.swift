//
//  ClipboardService.swift
//  keyDrop
//

import AppKit
import Foundation
import Observation

@Observable
final class ClipboardService {
    var clearAfter: TimeInterval = 30
    private(set) var clearsAt: Date?

    private var clearTimer: Timer?
    private var watchedChangeCount: Int = 0

    func copy(_ value: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)

        watchedChangeCount = pasteboard.changeCount
        let interval = max(30, clearAfter)
        let when = Date().addingTimeInterval(interval)
        clearsAt = when
        scheduleClear(after: interval)
    }

    func cancelPendingClear() {
        clearTimer?.invalidate()
        clearTimer = nil
        clearsAt = nil
    }

    private func scheduleClear(after interval: TimeInterval) {
        clearTimer?.invalidate()
        clearTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.performClearIfSafe()
        }
    }

    private func performClearIfSafe() {
        let pasteboard = NSPasteboard.general
        defer {
            clearsAt = nil
            clearTimer = nil
        }
        guard pasteboard.changeCount == watchedChangeCount else { return }
        pasteboard.clearContents()
    }
}
