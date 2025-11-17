//
//  EntryDetailView.swift
//  SecureVault
//

import SwiftUI

struct EntryDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var vaultManager: VaultManager
    @State var entry: VaultEntry
    @State private var showPassword = false
    @State private var showEdit = false
    @State private var showDelete = false
    @State private var copiedField: String?

    var body: some View {
        NavigationView {
            List {
                // Basic Info
                Section {
                    DetailRow(label: "Username", value: entry.username, canCopy: true, onCopy: { copiedField = "Username" })

                    HStack {
                        Text("Password")
                            .foregroundColor(.secondary)
                        Spacer()
                        if showPassword {
                            Text(entry.password)
                        } else {
                            Text(String(repeating: "•", count: min(entry.password.count, 12)))
                        }
                        Button(action: { showPassword.toggle() }) {
                            Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        }
                        Button(action: { copyToClipboard(entry.password); copiedField = "Password" }) {
                            Image(systemName: "doc.on.doc")
                        }
                    }
                }

                // URL
                if let url = entry.url, !url.isEmpty {
                    Section("Website") {
                        Link(destination: URL(string: url) ?? URL(string: "https://example.com")!) {
                            HStack {
                                Text(url)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                            }
                        }
                    }
                }

                // TOTP
                if entry.hasTOTP {
                    Section("2FA Code") {
                        TOTPCodeView(secret: entry.totpSecret!)
                    }
                }

                // Notes
                if let notes = entry.notes, !notes.isEmpty {
                    Section("Notes") {
                        Text(notes)
                    }
                }

                // Metadata
                Section {
                    DetailRow(label: "Category", value: entry.category.rawValue, canCopy: false, onCopy: {})
                    DetailRow(label: "Created", value: entry.createdAt.formatted(), canCopy: false, onCopy: {})
                    DetailRow(label: "Modified", value: entry.modifiedAt.formatted(), canCopy: false, onCopy: {})
                }
            }
            .navigationTitle(entry.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showEdit = true }) {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button(action: toggleFavorite) {
                            Label(entry.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                                  systemImage: entry.isFavorite ? "star.slash" : "star")
                        }

                        Button(role: .destructive, action: { showDelete = true }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Copied!", isPresented: .constant(copiedField != nil)) {
                Button("OK") { copiedField = nil }
            } message: {
                if let field = copiedField {
                    Text("\(field) copied to clipboard")
                }
            }
            .confirmationDialog("Delete Entry?", isPresented: $showDelete) {
                Button("Delete", role: .destructive) {
                    Task {
                        try? await vaultManager.deleteEntry(entry)
                        dismiss()
                    }
                }
            } message: {
                Text("This action cannot be undone")
            }
            .sheet(isPresented: $showEdit) {
                AddEditEntryView(entry: entry)
            }
        }
    }

    private func toggleFavorite() {
        Task {
            try? await vaultManager.toggleFavorite(entry)
            entry.isFavorite.toggle()
        }
    }

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    let canCopy: Bool
    let onCopy: () -> Void

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
            if canCopy {
                Button(action: {
                    UIPasteboard.general.string = value
                    onCopy()
                }) {
                    Image(systemName: "doc.on.doc")
                }
            }
        }
    }
}

import UIKit
