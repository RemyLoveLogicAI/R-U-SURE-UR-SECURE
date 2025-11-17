//
//  UnlockView.swift
//  SecureVault
//
//  Vault unlock screen with biometric authentication
//

import SwiftUI

struct UnlockView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @State private var password = ""
    @State private var isUnlocking = false
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var isPasswordFocused: Bool

    private let biometric = BiometricService.shared

    var body: some View {
        NavigationView {
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [.purple.opacity(0.6), .blue.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 30) {
                    Spacer()

                    // Logo
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                        .shadow(radius: 10)

                    Text("SecureVault")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)

                    Spacer()

                    // Biometric unlock button
                    if vaultManager.biometricEnabled && biometric.isBiometricAvailable() {
                        Button(action: unlockWithBiometric) {
                            HStack {
                                Image(systemName: biometric.biometricType().icon)
                                    .font(.title2)
                                Text("Unlock with \(biometric.biometricType().displayName)")
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.white.opacity(0.2))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .disabled(isUnlocking)

                        Text("or")
                            .foregroundColor(.white.opacity(0.7))
                    }

                    // Password field
                    SecureField("Master Password", text: $password)
                        .textContentType(.password)
                        .focused($isPasswordFocused)
                        .padding()
                        .background(.white.opacity(0.2))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .tint(.white)
                        .padding(.horizontal)
                        .onSubmit(unlockWithPassword)

                    Button(action: unlockWithPassword) {
                        if isUnlocking {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Unlock")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white.opacity(0.3))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .disabled(password.isEmpty || isUnlocking)

                    Spacer()
                }
                .padding()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                // Auto-trigger biometric on appear
                if vaultManager.biometricEnabled && biometric.isBiometricAvailable() {
                    Task {
                        await unlockWithBiometric()
                    }
                }
            }
        }
    }

    private func unlockWithPassword() {
        guard !password.isEmpty else { return }

        isUnlocking = true

        Task {
            do {
                try await vaultManager.unlock(password: password)
                password = "" // Clear password
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isUnlocking = false
        }
    }

    private func unlockWithBiometric() {
        isUnlocking = true

        Task {
            do {
                try await vaultManager.unlockWithBiometric()
            } catch {
                // Silent fail for biometric, allow password entry
                print("Biometric unlock failed: \(error)")
                isPasswordFocused = true
            }
            isUnlocking = false
        }
    }
}

#Preview {
    UnlockView()
        .environmentObject(VaultManager.shared)
}
