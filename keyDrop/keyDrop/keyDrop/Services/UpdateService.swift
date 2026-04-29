//
//  UpdateService.swift
//  keyDrop
//

import Combine
import Foundation

#if KEYDROP_CHANNEL_DIRECT
import Sparkle
#endif

@Observable
final class UpdateService: NSObject {
    #if KEYDROP_CHANNEL_DIRECT
    // Feed URL configured via SUFeedURL in Info-Direct.plist

    private let updaterController: SPUStandardUpdaterController
    private var cancellables = Set<AnyCancellable>()

    private(set) var canCheckForUpdates: Bool = false
    private(set) var lastUpdateCheckDate: Date?
    private(set) var isCheckingForUpdates: Bool = false

    var automaticallyChecksForUpdates: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set { updaterController.updater.automaticallyChecksForUpdates = newValue }
    }

    var automaticallyDownloadsUpdates: Bool {
        get { updaterController.updater.automaticallyDownloadsUpdates }
        set { updaterController.updater.automaticallyDownloadsUpdates = newValue }
    }

    var updateCheckInterval: TimeInterval {
        get { updaterController.updater.updateCheckInterval }
        set { updaterController.updater.updateCheckInterval = newValue }
    }

    override init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()

        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.canCheckForUpdates = value
            }
            .store(in: &cancellables)

        lastUpdateCheckDate = updaterController.updater.lastUpdateCheckDate
    }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        isCheckingForUpdates = true
        updaterController.checkForUpdates(nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.isCheckingForUpdates = false
            self?.lastUpdateCheckDate = self?.updaterController.updater.lastUpdateCheckDate
        }
    }

    #else
    // MAS builds use App Store updates - Sparkle is disabled
    private(set) var canCheckForUpdates: Bool = false
    private(set) var lastUpdateCheckDate: Date? = nil
    private(set) var isCheckingForUpdates: Bool = false
    var automaticallyChecksForUpdates: Bool = false
    var automaticallyDownloadsUpdates: Bool = false
    var updateCheckInterval: TimeInterval = 0

    override init() {
        super.init()
    }

    func checkForUpdates() {
        // No-op for MAS builds
    }
    #endif
}
