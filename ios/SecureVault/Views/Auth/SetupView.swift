//
//  SetupView.swift
//  SecureVault
//
//  Initial vault setup screen
//

import SwiftUI

struct SetupView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var enableBiometric = true
    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""

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

                ScrollView {
                    VStack(spacing: 25) {
                        // Header
                        VStack(spacing: 15) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 70))
                                .foregroundColor(.white)
                                .shadow(radius: 10)

                            Text("Welcome to SecureVault")
                                .font(.title.bold())
                                .foregroundColor(.white)

                            Text("Create a master password to secure your vault")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 50)
                        .padding(.bottom, 30)

                        // Password fields
                        VStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Master Password")
                                    .font(.headline)
                                    .foregroundColor(.white)

                                SecureField("Enter password", text: $password)
                                    .textContentType(.newPassword)
                                    .padding()
                                    .background(.white.opacity(0.2))
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                                    .tint(.white)

                                // Password strength indicator
                                PasswordStrengthView(password: password)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Confirm Password")
                                    .font(.headline)
                                    .foregroundColor(.white)

                                SecureField("Re-enter password", text: $confirmPassword)
                                    .textContentType(.newPassword)
                                    .padding()
                                    .background(.white.opacity(0.2))
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                                    .tint(.white)

                                if !confirmPassword.isEmpty && password != confirmPassword {
                                    HStack {
                                        Image(systemName: "xmark.circle.fill")
                                        Text("Passwords do not match")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.red)
                                }

                                if !password.isEmpty && password == confirmPassword {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Passwords match")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.green)
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Biometric toggle
                        if biometric.isBiometricAvailable() {
                            VStack(alignment: .leading, spacing: 12) {
                                Toggle(isOn: $enableBiometric) {
                                    HStack {
                                        Image(systemName: biometric.biometricType().icon)
                                        Text("Enable \(biometric.biometricType().displayName)")
                                    }
                                    .foregroundColor(.white)
                                }
                                .tint(.white)

                                Text("Unlock your vault quickly using \(biometric.biometricType().displayName)")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding()
                            .background(.white.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }

                        // Create button
                        Button(action: createVault) {
                            if isCreating {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Create Vault")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isCreateEnabled ? .white.opacity(0.3) : .white.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .disabled(!isCreateEnabled || isCreating)

                        // Security notice
                        VStack(spacing: 10) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text("Important")
                                    .font(.headline)
                            }
                            .foregroundColor(.yellow)

                            Text("Your master password cannot be recovered if forgotten. Make sure to remember it or store it safely.")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(.yellow.opacity(0.2))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        Spacer()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var isCreateEnabled: Bool {
        !password.isEmpty &&
        password.count >= 8 &&
        password == confirmPassword
    }

    private func createVault() {
        isCreating = true

        Task {
            do {
                try await vaultManager.createVault(masterPassword: password)
                vaultManager.biometricEnabled = enableBiometric

                password = ""
                confirmPassword = ""
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isCreating = false
        }
    }
}

struct PasswordStrengthView: View {
    let password: String

    private var strength: (level: Int, label: String, color: Color) {
        let length = password.count
        var level = 0

        if length >= 8 { level += 1 }
        if length >= 12 { level += 1 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil { level += 1 }
        if password.rangeOfCharacter(from: .lowercaseLetters) != nil { level += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil { level += 1 }
        if password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")) != nil { level += 1 }

        if level <= 2 {
            return (level, "Weak", .red)
        } else if level <= 4 {
            return (level, "Medium", .orange)
        } else {
            return (level, "Strong", .green)
        }
    }

    var body: some View {
        if !password.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Strength: \(strength.label)")
                        .font(.caption)
                        .foregroundColor(strength.color)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white.opacity(0.2))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(strength.color)
                            .frame(width: geometry.size.width * CGFloat(strength.level) / 6.0, height: 6)
                    }
                }
                .frame(height: 6)

                if strength.level < 4 {
                    Text("Use 12+ chars with uppercase, lowercase, numbers & symbols")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
    }
}

#Preview {
    SetupView()
        .environmentObject(VaultManager.shared)
}
