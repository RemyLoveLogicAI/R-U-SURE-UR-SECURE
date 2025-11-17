//
//  VaultManager.swift
//  SecureVault
//
//  Main vault manager coordinating all services
//  Handles vault state, encryption, and persistence
//

import Foundation
import Combine

@MainActor
final class VaultManager: ObservableObject {
    static let shared = VaultManager()

    // MARK: - Published Properties

    @Published private(set) var isUnlocked = false
    @Published private(set) var entries: [VaultEntry] = []
    @Published private(set) var isLoading = false
    @Published var error: VaultError?

    // MARK: - Private Properties

    private let keychain = KeychainService.shared
    private let crypto = CryptoService.shared
    private let biometric = BiometricService.shared

    private var autoLockTimer: Timer?
    private var autoLockTimeout: TimeInterval = 300 // 5 minutes

    private init() {
        setupAutoLock()
    }

    // MARK: - Vault State

    /// Check if vault exists
    var vaultExists: Bool {
        keychain.exists(for: KeychainService.Key.masterPasswordHash)
    }

    /// Check if biometric authentication is enabled
    var biometricEnabled: Bool {
        get {
            (try? keychain.read(for: KeychainService.Key.biometricEnabled, as: Bool.self)) ?? false
        }
        set {
            try? keychain.save(newValue, for: KeychainService.Key.biometricEnabled)
        }
    }

    // MARK: - Vault Creation

    /// Create new vault with master password
    func createVault(masterPassword: String) async throws {
        guard !masterPassword.isEmpty else {
            throw VaultError.invalidPassword
        }

        guard !vaultExists else {
            throw VaultError.vaultAlreadyExists
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Hash master password
            let (hash, salt) = try crypto.hashPassword(masterPassword)
            let hashData = hash + salt

            try keychain.save(hashData, for: KeychainService.Key.masterPasswordHash)

            // Generate and store encryption key
            let encryptionKey = crypto.generateEncryptionKey()
            try keychain.save(encryptionKey, for: KeychainService.Key.encryptionKey)

            // Initialize empty vault
            entries = []
            try await saveVault()

            isUnlocked = true
        } catch {
            throw VaultError.creationFailed(error)
        }
    }

    // MARK: - Unlock/Lock

    /// Unlock vault with master password
    func unlock(password: String) async throws {
        guard vaultExists else {
            throw VaultError.vaultNotFound
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Verify master password
            let hashData = try keychain.read(for: KeychainService.Key.masterPasswordHash)
            let saltOffset = hashData.count - 32
            let storedHash = hashData.prefix(saltOffset)
            let salt = hashData.suffix(32)

            let isValid = try crypto.verifyPassword(password, hash: storedHash, salt: salt)
            guard isValid else {
                throw VaultError.incorrectPassword
            }

            // Load vault data
            try await loadVault()

            isUnlocked = true
            resetAutoLockTimer()
        } catch let error as VaultError {
            throw error
        } catch {
            throw VaultError.unlockFailed(error)
        }
    }

    /// Unlock vault with biometric authentication
    func unlockWithBiometric() async throws {
        guard biometricEnabled else {
            throw VaultError.biometricNotEnabled
        }

        do {
            try await biometric.authenticate()

            // Load vault data
            try await loadVault()

            isUnlocked = true
            resetAutoLockTimer()
        } catch let error as BiometricError {
            throw VaultError.biometricFailed(error)
        } catch {
            throw VaultError.unlockFailed(error)
        }
    }

    /// Lock vault
    func lock() {
        isUnlocked = false
        entries = []
        autoLockTimer?.invalidate()
        autoLockTimer = nil
    }

    // MARK: - Entry Management

    /// Add new entry
    func addEntry(_ entry: VaultEntry) async throws {
        guard isUnlocked else {
            throw VaultError.vaultLocked
        }

        entries.append(entry)
        try await saveVault()
    }

    /// Update existing entry
    func updateEntry(_ entry: VaultEntry) async throws {
        guard isUnlocked else {
            throw VaultError.vaultLocked
        }

        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else {
            throw VaultError.entryNotFound
        }

        var updatedEntry = entry
        updatedEntry.touch()
        entries[index] = updatedEntry
        try await saveVault()
    }

    /// Delete entry
    func deleteEntry(_ entry: VaultEntry) async throws {
        guard isUnlocked else {
            throw VaultError.vaultLocked
        }

        entries.removeAll(where: { $0.id == entry.id })
        try await saveVault()
    }

    /// Delete entries
    func deleteEntries(at offsets: IndexSet) async throws {
        guard isUnlocked else {
            throw VaultError.vaultLocked
        }

        entries.remove(atOffsets: offsets)
        try await saveVault()
    }

    /// Toggle favorite
    func toggleFavorite(_ entry: VaultEntry) async throws {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else {
            throw VaultError.entryNotFound
        }

        entries[index].isFavorite.toggle()
        entries[index].touch()
        try await saveVault()
    }

    // MARK: - Search & Filter

    /// Search entries
    func searchEntries(query: String) -> [VaultEntry] {
        guard !query.isEmpty else {
            return entries
        }

        let lowercasedQuery = query.lowercased()
        return entries.filter {
            $0.name.lowercased().contains(lowercasedQuery) ||
            $0.username.lowercased().contains(lowercasedQuery) ||
            $0.url?.lowercased().contains(lowercasedQuery) == true
        }
    }

    /// Filter entries by category
    func filterEntries(by category: VaultEntry.Category) -> [VaultEntry] {
        entries.filter { $0.category == category }
    }

    /// Get favorite entries
    var favoriteEntries: [VaultEntry] {
        entries.filter { $0.isFavorite }
    }

    // MARK: - Import/Export

    /// Export vault to encrypted JSON
    func exportVault(password: String) async throws -> Data {
        guard isUnlocked else {
            throw VaultError.vaultLocked
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(entries)

        let encrypted = try crypto.encrypt(jsonData, password: password)
        return try JSONEncoder().encode(encrypted)
    }

    /// Import vault from encrypted JSON
    func importVault(data: Data, password: String) async throws {
        guard isUnlocked else {
            throw VaultError.vaultLocked
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let encrypted = try decoder.decode(EncryptedData.self, from: data)
        let decrypted = try crypto.decrypt(encrypted, password: password)

        let importedEntries = try decoder.decode([VaultEntry].self, from: decrypted)

        // Merge or replace entries
        entries.append(contentsOf: importedEntries)
        try await saveVault()
    }

    // MARK: - Password Change

    /// Change master password
    func changeMasterPassword(currentPassword: String, newPassword: String) async throws {
        guard isUnlocked else {
            throw VaultError.vaultLocked
        }

        // Verify current password
        let hashData = try keychain.read(for: KeychainService.Key.masterPasswordHash)
        let saltOffset = hashData.count - 32
        let storedHash = hashData.prefix(saltOffset)
        let salt = hashData.suffix(32)

        let isValid = try crypto.verifyPassword(currentPassword, hash: storedHash, salt: salt)
        guard isValid else {
            throw VaultError.incorrectPassword
        }

        // Hash new password
        let (newHash, newSalt) = try crypto.hashPassword(newPassword)
        let newHashData = newHash + newSalt

        try keychain.save(newHashData, for: KeychainService.Key.masterPasswordHash)
    }

    // MARK: - Private Methods

    private func saveVault() async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entries)

        let encrypted = try crypto.encryptWithStoredKey(data)
        try keychain.save(encrypted, for: KeychainService.Key.vaultData)
    }

    private func loadVault() async throws {
        do {
            let encrypted = try keychain.read(for: KeychainService.Key.vaultData)
            let decrypted = try crypto.decryptWithStoredKey(encrypted)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            entries = try decoder.decode([VaultEntry].self, from: decrypted)
        } catch KeychainError.itemNotFound {
            // New vault, no entries yet
            entries = []
        }
    }

    // MARK: - Auto-Lock

    private func setupAutoLock() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func appDidEnterBackground() {
        if isUnlocked {
            autoLockTimer?.invalidate()
            // Lock immediately when app goes to background
            lock()
        }
    }

    @objc private func appWillEnterForeground() {
        // User must unlock again when returning
    }

    private func resetAutoLockTimer() {
        autoLockTimer?.invalidate()

        autoLockTimer = Timer.scheduledTimer(withTimeInterval: autoLockTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.lock()
            }
        }
    }
}

// MARK: - Errors

enum VaultError: LocalizedError {
    case vaultNotFound
    case vaultAlreadyExists
    case vaultLocked
    case invalidPassword
    case incorrectPassword
    case entryNotFound
    case biometricNotEnabled
    case biometricFailed(BiometricError)
    case creationFailed(Error)
    case unlockFailed(Error)
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .vaultNotFound:
            return "No vault found. Please create a new vault"
        case .vaultAlreadyExists:
            return "A vault already exists"
        case .vaultLocked:
            return "Vault is locked. Please unlock first"
        case .invalidPassword:
            return "Password cannot be empty"
        case .incorrectPassword:
            return "Incorrect password"
        case .entryNotFound:
            return "Entry not found"
        case .biometricNotEnabled:
            return "Biometric authentication is not enabled"
        case .biometricFailed(let error):
            return error.localizedDescription
        case .creationFailed(let error):
            return "Failed to create vault: \(error.localizedDescription)"
        case .unlockFailed(let error):
            return "Failed to unlock vault: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save vault: \(error.localizedDescription)"
        }
    }
}

// UIKit import for notifications
import UIKit
