//
//  AddEditEntryView.swift
//  SecureVault
//

import SwiftUI

struct AddEditEntryView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var vaultManager: VaultManager

    @State var entry: VaultEntry?
    @State private var name = ""
    @State private var username = ""
    @State private var password = ""
    @State private var url = ""
    @State private var notes = ""
    @State private var category: VaultEntry.Category = .login
    @State private var totpSecret = ""

    var isEditing: Bool { entry != nil }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .autocapitalization(.none)
                    
                    HStack {
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                        Button(action: generatePassword) {
                            Image(systemName: "wand.and.stars")
                        }
                    }
                }

                Section("Optional") {
                    TextField("Website URL", text: $url)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                    TextField("2FA Secret (Base32)", text: $totpSecret)
                        .autocapitalization(.allCharacters)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }

                Section {
                    Picker("Category", selection: $category) {
                        ForEach(VaultEntry.Category.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Entry" : "New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveEntry() }
                        .disabled(name.isEmpty)
                }
            }
            .onAppear(perform: loadEntry)
        }
    }

    private func loadEntry() {
        guard let entry = entry else { return }
        name = entry.name
        username = entry.username
        password = entry.password
        url = entry.url ?? ""
        notes = entry.notes ?? ""
        category = entry.category
        totpSecret = entry.totpSecret ?? ""
    }

    private func generatePassword() {
        password = CryptoService.shared.generatePassword(length: 16)
    }

    private func saveEntry() {
        let newEntry = VaultEntry(
            id: entry?.id ?? UUID(),
            name: name,
            username: username,
            password: password,
            url: url.isEmpty ? nil : url,
            notes: notes.isEmpty ? nil : notes,
            category: category,
            totpSecret: totpSecret.isEmpty ? nil : totpSecret
        )

        Task {
            if isEditing {
                try? await vaultManager.updateEntry(newEntry)
            } else {
                try? await vaultManager.addEntry(newEntry)
            }
            dismiss()
        }
    }
}
