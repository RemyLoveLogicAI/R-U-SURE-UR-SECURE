//
//  CryptoService.swift
//  SecureVault
//
//  Encryption and cryptographic operations using CryptoKit
//  AES-256-GCM with PBKDF2 key derivation
//

import Foundation
import CryptoKit

enum CryptoError: Error {
    case encryptionFailed
    case decryptionFailed
    case invalidPassword
    case keyDerivationFailed
    case invalidData
}

final class CryptoService {
    static let shared = CryptoService()

    private let saltLength = 32 // 256 bits
    private let keyDerivationIterations = 100_000

    private init() {}

    // MARK: - Password Hashing

    /// Hash password using PBKDF2
    func hashPassword(_ password: String, salt: Data? = nil) throws -> (hash: Data, salt: Data) {
        let usedSalt = salt ?? generateSalt()

        guard let passwordData = password.data(using: .utf8) else {
            throw CryptoError.invalidPassword
        }

        let hash = try deriveKey(from: passwordData, salt: usedSalt)
        return (hash, usedSalt)
    }

    /// Verify password against stored hash
    func verifyPassword(_ password: String, hash: Data, salt: Data) throws -> Bool {
        let (computedHash, _) = try hashPassword(password, salt: salt)
        return computedHash == hash
    }

    // MARK: - Encryption/Decryption

    /// Encrypt data with password
    func encrypt(_ data: Data, password: String) throws -> EncryptedData {
        let salt = generateSalt()
        guard let passwordData = password.data(using: .utf8) else {
            throw CryptoError.invalidPassword
        }

        let key = try deriveKey(from: passwordData, salt: salt)
        let symmetricKey = SymmetricKey(data: key)

        let nonce = AES.GCM.Nonce()

        guard let sealedBox = try? AES.GCM.seal(data, using: symmetricKey, nonce: nonce) else {
            throw CryptoError.encryptionFailed
        }

        return EncryptedData(
            ciphertext: sealedBox.ciphertext,
            nonce: nonce.withUnsafeBytes { Data($0) },
            tag: sealedBox.tag,
            salt: salt
        )
    }

    /// Decrypt data with password
    func decrypt(_ encryptedData: EncryptedData, password: String) throws -> Data {
        guard let passwordData = password.data(using: .utf8) else {
            throw CryptoError.invalidPassword
        }

        let key = try deriveKey(from: passwordData, salt: encryptedData.salt)
        let symmetricKey = SymmetricKey(data: key)

        guard let nonce = try? AES.GCM.Nonce(data: encryptedData.nonce) else {
            throw CryptoError.invalidData
        }

        guard let sealedBox = try? AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: encryptedData.ciphertext,
            tag: encryptedData.tag
        ) else {
            throw CryptoError.invalidData
        }

        guard let decryptedData = try? AES.GCM.open(sealedBox, using: symmetricKey) else {
            throw CryptoError.decryptionFailed
        }

        return decryptedData
    }

    // MARK: - Encryption with Stored Key

    /// Encrypt using stored encryption key (for quick access after unlock)
    func encryptWithStoredKey(_ data: Data) throws -> Data {
        guard let key = try? KeychainService.shared.read(for: KeychainService.Key.encryptionKey) else {
            throw CryptoError.encryptionFailed
        }

        let symmetricKey = SymmetricKey(data: key)
        let nonce = AES.GCM.Nonce()

        guard let sealedBox = try? AES.GCM.seal(data, using: symmetricKey, nonce: nonce) else {
            throw CryptoError.encryptionFailed
        }

        // Combine nonce + tag + ciphertext for storage
        var combined = Data()
        combined.append(nonce.withUnsafeBytes { Data($0) })
        combined.append(sealedBox.tag)
        combined.append(sealedBox.ciphertext)

        return combined
    }

    /// Decrypt using stored encryption key
    func decryptWithStoredKey(_ data: Data) throws -> Data {
        guard let key = try? KeychainService.shared.read(for: KeychainService.Key.encryptionKey) else {
            throw CryptoError.decryptionFailed
        }

        // Extract nonce (12 bytes) + tag (16 bytes) + ciphertext
        let nonceSize = 12
        let tagSize = 16

        guard data.count > nonceSize + tagSize else {
            throw CryptoError.invalidData
        }

        let nonceData = data.prefix(nonceSize)
        let tagData = data.dropFirst(nonceSize).prefix(tagSize)
        let ciphertext = data.dropFirst(nonceSize + tagSize)

        guard let nonce = try? AES.GCM.Nonce(data: nonceData) else {
            throw CryptoError.invalidData
        }

        let symmetricKey = SymmetricKey(data: key)

        guard let sealedBox = try? AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: ciphertext,
            tag: tagData
        ) else {
            throw CryptoError.invalidData
        }

        guard let decryptedData = try? AES.GCM.open(sealedBox, using: symmetricKey) else {
            throw CryptoError.decryptionFailed
        }

        return decryptedData
    }

    // MARK: - Key Generation

    /// Generate random encryption key
    func generateEncryptionKey() -> Data {
        var keyData = Data(count: 32) // 256 bits
        _ = keyData.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!)
        }
        return keyData
    }

    /// Generate password with specified requirements
    func generatePassword(
        length: Int = 16,
        includeUppercase: Bool = true,
        includeLowercase: Bool = true,
        includeNumbers: Bool = true,
        includeSymbols: Bool = true
    ) -> String {
        var characterSet = ""

        if includeUppercase { characterSet += "ABCDEFGHIJKLMNOPQRSTUVWXYZ" }
        if includeLowercase { characterSet += "abcdefghijklmnopqrstuvwxyz" }
        if includeNumbers { characterSet += "0123456789" }
        if includeSymbols { characterSet += "!@#$%^&*()_+-=[]{}|;:,.<>?" }

        guard !characterSet.isEmpty else { return "" }

        var password = ""
        for _ in 0..<length {
            let randomIndex = Int.random(in: 0..<characterSet.count)
            let character = characterSet[characterSet.index(characterSet.startIndex, offsetBy: randomIndex)]
            password.append(character)
        }

        return password
    }

    // MARK: - Private Helpers

    private func generateSalt() -> Data {
        var saltData = Data(count: saltLength)
        _ = saltData.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, saltLength, $0.baseAddress!)
        }
        return saltData
    }

    private func deriveKey(from password: Data, salt: Data) throws -> Data {
        guard let key = try? PBKDF2.deriveKey(
            password: password,
            salt: salt,
            iterations: keyDerivationIterations,
            keyLength: 32 // 256 bits
        ) else {
            throw CryptoError.keyDerivationFailed
        }
        return key
    }
}

// MARK: - Supporting Types

struct EncryptedData: Codable {
    let ciphertext: Data
    let nonce: Data
    let tag: Data
    let salt: Data
    let version: Int = 1
}

// MARK: - PBKDF2 Implementation

enum PBKDF2 {
    static func deriveKey(
        password: Data,
        salt: Data,
        iterations: Int,
        keyLength: Int
    ) throws -> Data {
        var derivedKeyData = Data(count: keyLength)

        let derivationStatus = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                password.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        password.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keyLength
                    )
                }
            }
        }

        guard derivationStatus == kCCSuccess else {
            throw CryptoError.keyDerivationFailed
        }

        return derivedKeyData
    }
}

// Required for CCKeyDerivationPBKDF
import CommonCrypto
