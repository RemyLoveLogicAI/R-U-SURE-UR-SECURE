//
//  SecureVaultApp.swift
//  SecureVault
//
//  Main app entry point
//

import SwiftUI

@main
struct SecureVaultApp: App {
    @StateObject private var vaultManager = VaultManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vaultManager)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var vaultManager: VaultManager

    var body: some View {
        Group {
            if vaultManager.isUnlocked {
                MainTabView()
            } else if vaultManager.vaultExists {
                UnlockView()
            } else {
                SetupView()
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            VaultListView()
                .tabItem {
                    Label("Vault", systemImage: "lock.fill")
                }

            TOTPListView()
                .tabItem {
                    Label("2FA", systemImage: "timer")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}
