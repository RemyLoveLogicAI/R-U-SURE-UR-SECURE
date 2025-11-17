//
//  BiometricService.swift
//  SecureVault
//
//  Biometric authentication (Face ID / Touch ID) service
//

import Foundation
import LocalAuthentication

enum BiometricType {
    case none
    case faceID
    case touchID
    case opticID // For future Vision Pro support

    var displayName: String {
        switch self {
        case .none: return "None"
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        }
    }

    var icon: String {
        switch self {
        case .none: return "lock.fill"
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "eye.fill"
        }
    }
}

enum BiometricError: Error {
    case notAvailable
    case notEnrolled
    case authenticationFailed
    case userCancel
    case systemCancel
    case passcodeNotSet
    case biometryLockout
    case unknown(Error)

    var localizedDescription: String {
        switch self {
        case .notAvailable:
            return "Biometric authentication is not available on this device"
        case .notEnrolled:
            return "No biometric authentication is enrolled. Please set up Face ID or Touch ID in Settings"
        case .authenticationFailed:
            return "Biometric authentication failed"
        case .userCancel:
            return "Authentication was cancelled"
        case .systemCancel:
            return "Authentication was cancelled by the system"
        case .passcodeNotSet:
            return "Passcode is not set on this device"
        case .biometryLockout:
            return "Biometric authentication is locked. Please try again later"
        case .unknown(let error):
            return "Authentication error: \(error.localizedDescription)"
        }
    }
}

final class BiometricService {
    static let shared = BiometricService()

    private let context = LAContext()

    private init() {}

    // MARK: - Availability

    /// Check if biometrics are available
    func isBiometricAvailable() -> Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Get the type of biometric authentication available
    func biometricType() -> BiometricType {
        guard isBiometricAvailable() else {
            return .none
        }

        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            return .opticID
        case .none:
            return .none
        @unknown default:
            return .none
        }
    }

    // MARK: - Authentication

    /// Authenticate with biometrics
    func authenticate(reason: String = "Authenticate to access your vault") async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Use Password"
        context.localizedFallbackTitle = "Use Password"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                throw mapError(error)
            }
            throw BiometricError.notAvailable
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )

            guard success else {
                throw BiometricError.authenticationFailed
            }
        } catch let error as LAError {
            throw mapError(error)
        } catch {
            throw BiometricError.unknown(error)
        }
    }

    /// Authenticate with biometrics or passcode fallback
    func authenticateWithFallback(reason: String = "Authenticate to access your vault") async throws {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )

            guard success else {
                throw BiometricError.authenticationFailed
            }
        } catch let error as LAError {
            throw mapError(error)
        } catch {
            throw BiometricError.unknown(error)
        }
    }

    // MARK: - Private Helpers

    private func mapError(_ error: Error) -> BiometricError {
        guard let laError = error as? LAError else {
            return .unknown(error)
        }

        switch laError.code {
        case .authenticationFailed:
            return .authenticationFailed
        case .userCancel:
            return .userCancel
        case .systemCancel:
            return .systemCancel
        case .passcodeNotSet:
            return .passcodeNotSet
        case .biometryNotAvailable:
            return .notAvailable
        case .biometryNotEnrolled:
            return .notEnrolled
        case .biometryLockout:
            return .biometryLockout
        default:
            return .unknown(error)
        }
    }
}
