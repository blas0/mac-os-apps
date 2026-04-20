//
//  KeyStore.swift
//  keyDrop
//

import AppKit
import Foundation
import LocalAuthentication
import Observation

@Observable
final class KeyStore {
    private(set) var entries: [KeyEntry] = []
    private(set) var revealedValues: [UUID: String] = [:]
    var lastError: String?

    let auth = AuthService()
    let clipboard = ClipboardService()

    private let metadataURL: URL
    private var menuPinTask: Task<Void, Never>?

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("keyDrop", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.metadataURL = dir.appendingPathComponent("entries.json")
        loadFromDisk()
        auth.onInvalidate = { [weak self] in
            self?.revealedValues.removeAll()
        }
    }

    func add(label: String, key: String) {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty, !trimmedKey.isEmpty else { return }

        if entries.contains(where: { $0.label.caseInsensitiveCompare(trimmedLabel) == .orderedSame }) {
            lastError = "A key labelled \"\(trimmedLabel)\" already exists. Delete it first or pick a new label."
            return
        }

        let entry = KeyEntry(
            id: UUID(),
            label: trimmedLabel,
            createdAt: Date(),
            keyPreview: KeyEntry.makePreview(from: trimmedKey)
        )

        do {
            try KeychainService.save(account: entry.keychainAccount, value: trimmedKey)
            entries.insert(entry, at: 0)
            persist()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func copyKey(_ entry: KeyEntry, completion: ((Bool) -> Void)? = nil) {
        authenticate(reason: "Copy \(entry.label) to your clipboard") { [weak self] success in
            guard let self else { completion?(false); return }
            guard success else { completion?(false); return }
            do {
                let value = try KeychainService.load(account: entry.keychainAccount)
                self.clipboard.copy(value)
                self.revealedValues[entry.id] = value
                self.bulkLoadRevealed()
                self.lastError = nil
                completion?(true)
            } catch {
                self.lastError = error.localizedDescription
                completion?(false)
            }
        }
    }

    func revealKey(_ entry: KeyEntry, completion: @escaping (String?) -> Void) {
        authenticate(reason: "Reveal \(entry.label)") { [weak self] success in
            guard let self, success else { completion(nil); return }
            do {
                let value = try KeychainService.load(account: entry.keychainAccount)
                self.revealedValues[entry.id] = value
                self.bulkLoadRevealed()
                self.lastError = nil
                completion(value)
            } catch {
                self.lastError = error.localizedDescription
                completion(nil)
            }
        }
    }

    func deleteWithAuth(_ entry: KeyEntry, completion: ((Bool) -> Void)? = nil) {
        authenticate(reason: "Delete \(entry.label)") { [weak self] success in
            guard let self, success else { completion?(false); return }
            do {
                try KeychainService.delete(account: entry.keychainAccount)
                self.entries.removeAll { $0.id == entry.id }
                self.revealedValues.removeValue(forKey: entry.id)
                self.persist()
                self.lastError = nil
                completion?(true)
            } catch {
                self.lastError = error.localizedDescription
                completion?(false)
            }
        }
    }

    private func bulkLoadRevealed() {
        for entry in entries where revealedValues[entry.id] == nil {
            if let value = try? KeychainService.load(account: entry.keychainAccount) {
                revealedValues[entry.id] = value
            }
        }
    }

    private func authenticate(reason: String, _ completion: @escaping (Bool) -> Void) {
        if auth.isWithinGrace {
            completion(true)
            return
        }
        let context = LAContext()
        var probeError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &probeError) else {
            lastError = probeError?.localizedDescription ?? "Biometric authentication is unavailable on this Mac."
            completion(false)
            return
        }

        auth.beginAuth()
        startMenuPinWatchdog()

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self else { completion(false); return }
                if success {
                    self.auth.didAuthenticate(with: context)
                    self.auth.endAuth()
                    completion(true)
                } else {
                    self.auth.endAuth()
                    self.lastError = error?.localizedDescription ?? "Authentication failed."
                    completion(false)
                }
            }
        }
    }

    private func startMenuPinWatchdog() {
        menuPinTask?.cancel()
        menuPinTask = Task { @MainActor in
            while !Task.isCancelled, auth.shouldPinMenu {
                pinMenuBarWindow()
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
    }

    @MainActor
    private func pinMenuBarWindow() {
        for window in NSApp.windows where isMenuBarExtraWindow(window) {
            window.hidesOnDeactivate = false
            if !window.isVisible {
                window.orderFrontRegardless()
            }
        }
    }

    @MainActor
    private func isMenuBarExtraWindow(_ window: NSWindow) -> Bool {
        let name = String(describing: type(of: window))
        if name.contains("MenuBarExtra") { return true }
        if name.contains("StatusBar") { return true }
        return false
    }

    func updateEntry(id: UUID, newLabel: String, newKey: String, completion: ((Bool) -> Void)? = nil) {
        let trimmedLabel = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty, !trimmedKey.isEmpty,
              let idx = entries.firstIndex(where: { $0.id == id }) else {
            lastError = "Label and key cannot be empty."
            completion?(false)
            return
        }
        let collision = entries.contains { other in
            other.id != id && other.label.caseInsensitiveCompare(trimmedLabel) == .orderedSame
        }
        if collision {
            lastError = "Another key already uses the label \"\(trimmedLabel)\"."
            completion?(false)
            return
        }
        let entry = entries[idx]
        do {
            try KeychainService.delete(account: entry.keychainAccount)
            try KeychainService.save(account: entry.keychainAccount, value: trimmedKey)
            entries[idx].label = trimmedLabel
            entries[idx].keyPreview = KeyEntry.makePreview(from: trimmedKey)
            revealedValues[id] = trimmedKey
            persist()
            lastError = nil
            completion?(true)
        } catch {
            lastError = error.localizedDescription
            completion?(false)
        }
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: metadataURL) else {
            entries = []
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode([KeyEntry].self, from: data) else {
            entries = []
            return
        }
        entries = decoded.sorted { $0.createdAt > $1.createdAt }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(entries)
            try data.write(to: metadataURL, options: [.atomic])
        } catch {
            lastError = "Failed to persist metadata: \(error.localizedDescription)"
        }
    }
}
