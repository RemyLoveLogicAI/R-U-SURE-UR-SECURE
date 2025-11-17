//
//  VaultEntry.swift
//  SecureVault
//
//  Created by SecureVault Team
//  Copyright © 2025 SecureVault. All rights reserved.
//

import Foundation
import SwiftUI

/// Main model for password vault entries
struct VaultEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var username: String
    var password: String
    var url: String?
    var notes: String?
    var category: Category
    var isFavorite: Bool
    var createdAt: Date
    var modifiedAt: Date
    var totpSecret: String?
    var customFields: [CustomField]

    enum Category: String, Codable, CaseIterable {
        case login = "Login"
        case creditCard = "Credit Card"
        case secureNote = "Secure Note"
        case apiKey = "API Key"
        case wifi = "WiFi"
        case identity = "Identity"

        var icon: String {
            switch self {
            case .login: return "key.fill"
            case .creditCard: return "creditcard.fill"
            case .secureNote: return "note.text"
            case .apiKey: return "chevron.left.forwardslash.chevron.right"
            case .wifi: return "wifi"
            case .identity: return "person.fill"
            }
        }

        var color: Color {
            switch self {
            case .login: return .blue
            case .creditCard: return .green
            case .secureNote: return .orange
            case .apiKey: return .purple
            case .wifi: return .cyan
            case .identity: return .pink
            }
        }
    }

    struct CustomField: Identifiable, Codable, Hashable {
        let id: UUID
        var label: String
        var value: String
        var isSecret: Bool

        init(id: UUID = UUID(), label: String, value: String, isSecret: Bool = false) {
            self.id = id
            self.label = label
            self.value = value
            self.isSecret = isSecret
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        username: String = "",
        password: String = "",
        url: String? = nil,
        notes: String? = nil,
        category: Category = .login,
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        totpSecret: String? = nil,
        customFields: [CustomField] = []
    ) {
        self.id = id
        self.name = name
        self.username = username
        self.password = password
        self.url = url
        self.notes = notes
        self.category = category
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.totpSecret = totpSecret
        self.customFields = customFields
    }

    /// Update modification timestamp
    mutating func touch() {
        modifiedAt = Date()
    }

    /// Get domain from URL
    var domain: String? {
        guard let urlString = url,
              let url = URL(string: urlString),
              let host = url.host else {
            return nil
        }
        return host
    }

    /// Check if entry has TOTP
    var hasTOTP: Bool {
        totpSecret != nil && !totpSecret!.isEmpty
    }
}

// MARK: - Sample Data
extension VaultEntry {
    static let samples: [VaultEntry] = [
        VaultEntry(
            name: "GitHub",
            username: "user@example.com",
            password: "SecureP@ssw0rd123!",
            url: "https://github.com",
            category: .login,
            isFavorite: true,
            totpSecret: "JBSWY3DPEHPK3PXP"
        ),
        VaultEntry(
            name: "OpenAI API",
            username: "Production",
            password: "sk-proj-1234567890abcdef",
            url: "https://platform.openai.com",
            notes: "Rate limit: 10k RPM",
            category: .apiKey
        ),
        VaultEntry(
            name: "Personal Notes",
            username: "",
            password: "",
            notes: "Important information stored securely",
            category: .secureNote
        )
    ]
}
