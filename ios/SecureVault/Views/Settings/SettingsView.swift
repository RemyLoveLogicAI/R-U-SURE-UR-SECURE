//
//  SettingsView.swift
//  SecureVault
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @State private var showExport = false
    @State private var showImport = false
    @State private var showChangePassword = false
    @State private var showLockConfirm = false

    private let biometric = BiometricService.shared

    var body: some View {
        NavigationView {
            List {
                // Security
                Section("Security") {
                    if biometric.isBiometricAvailable() {
                        Toggle(isOn: Binding(
                            get: { vaultManager.biometricEnabled },
                            set: { vaultManager.biometricEnabled = $0 }
                        )) {
                            HStack {
                                Image(systemName: biometric.biometricType().icon)
                                Text(biometric.biometricType().displayName)
                            }
                        }
                    }

                    Button(action: { showChangePassword = true }) {
                        Label("Change Master Password", systemImage: "key.fill")
                    }

                    Button(action: { showLockConfirm = true }) {
                        Label("Lock Vault", systemImage: "lock.fill")
                    }
                }

                // Data
                Section("Data") {
                    Button(action: { showExport = true }) {
                        Label("Export Vault", systemImage: "square.and.arrow.up")
                    }

                    Button(action: { showImport = true }) {
                        Label("Import Vault", systemImage: "square.and.arrow.down")
                    }
                }

                // Info
                Section {
                    HStack {
                        Text("Total Entries")
                        Spacer()
                        Text("\(vaultManager.entries.count)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }

                // About
                Section {
                    Link(destination: URL(string: "https://github.com/RemyLoveLogicAI/R-U-SURE-UR-SECURE")!) {
                        HStack {
                            Label("GitHub Repository", systemImage: "link")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showExport) {
                ExportView()
            }
            .sheet(isPresented: $showImport) {
                ImportView()
            }
            .sheet(isPresented: $showChangePassword) {
                ChangePasswordView()
            }
            .confirmationDialog("Lock Vault?", isPresented: $showLockConfirm) {
                Button("Lock", role: .destructive) {
                    vaultManager.lock()
                }
            }
        }
    }
}

struct ExportView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var vaultManager: VaultManager
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isExporting = false
    @State private var exportedData: Data?

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Enter a password to encrypt your vault export")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    SecureField("Password", text: $password)
                    SecureField("Confirm Password", text: $confirmPassword)

                    if !password.isEmpty && password != confirmPassword {
                        Text("Passwords do not match")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button(action: exportVault) {
                        if isExporting {
                            ProgressView()
                        } else {
                            Text("Export")
                        }
                    }
                    .disabled(password.isEmpty || password != confirmPassword)
                }
            }
            .navigationTitle("Export Vault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: Binding(
                get: { exportedData.map { ShareItem(data: $0) } },
                set: { exportedData = $0?.data }
            )) { item in
                ShareSheet(items: [item.data])
            }
        }
    }

    private func exportVault() {
        isExporting = true
        Task {
            do {
                let data = try await vaultManager.exportVault(password: password)
                exportedData = data
            } catch {
                print("Export failed: \(error)")
            }
            isExporting = false
        }
    }
}

struct ImportView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var vaultManager: VaultManager
    @State private var password = ""
    @State private var isImporting = false
    @State private var showFilePicker = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Select exported vault file and enter the password used during export")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button("Select File") {
                        showFilePicker = true
                    }

                    SecureField("Decryption Password", text: $password)
                }
            }
            .navigationTitle("Import Vault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct ChangePasswordView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var vaultManager: VaultManager
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isChanging = false
    @State private var error: String?

    var body: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("Current Password", text: $currentPassword)
                    SecureField("New Password", text: $newPassword)
                    SecureField("Confirm New Password", text: $confirmPassword)

                    if !newPassword.isEmpty && newPassword != confirmPassword {
                        Text("Passwords do not match")
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    if let error = error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button(action: changePassword) {
                        if isChanging {
                            ProgressView()
                        } else {
                            Text("Change Password")
                        }
                    }
                    .disabled(currentPassword.isEmpty || newPassword.isEmpty || newPassword != confirmPassword)
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func changePassword() {
        isChanging = true
        error = nil

        Task {
            do {
                try await vaultManager.changeMasterPassword(
                    currentPassword: currentPassword,
                    newPassword: newPassword
                )
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isChanging = false
        }
    }
}

// Helper types
struct ShareItem: Identifiable {
    let id = UUID()
    let data: Data
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

import UIKit
