//
//  LicenseService.swift
//  keyDrop
//
//  Homebrew distribution is free; no runtime license activation is required.
//

import Foundation

@Observable
final class LicenseService {
    var isLicensed: Bool { true }
    var isValidating: Bool { false }
    var licenseInfo: LicenseInfo? { nil }
    var lastError: LicenseError? { nil }

    struct LicenseInfo: Codable {
        let licenseKey: String
        let email: String
        let purchaseDate: Date
        let validatedAt: Date
    }

    enum LicenseError: Error {
        case invalidKey
    }

    func validateLicense(key: String) async -> Bool { true }
    func clearLicense() {}
}
