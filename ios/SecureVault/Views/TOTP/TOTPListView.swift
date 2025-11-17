//
//  TOTPListView.swift
//  SecureVault
//

import SwiftUI

struct TOTPListView: View {
    @EnvironmentObject var vaultManager: VaultManager

    var totpEntries: [VaultEntry] {
        vaultManager.entries.filter { $0.hasTOTP }
    }

    var body: some View {
        NavigationView {
            List {
                if totpEntries.isEmpty {
                    ContentUnavailableView(
                        "No 2FA Codes",
                        systemImage: "timer",
                        description: Text("Add entries with TOTP secrets to see codes here")
                    )
                } else {
                    ForEach(totpEntries) { entry in
                        TOTPEntryRow(entry: entry)
                    }
                }
            }
            .navigationTitle("2FA Codes")
        }
    }
}

struct TOTPEntryRow: View {
    let entry: VaultEntry
    @State private var code: String?
    @State private var remainingSeconds = 30

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(entry.name)
                .font(.headline)

            if let code = code {
                HStack {
                    Text(formattedCode(code))
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.medium)

                    Spacer()

                    Button(action: {
                        UIPasteboard.general.string = code
                    }) {
                        Image(systemName: "doc.on.doc")
                            .imageScale(.large)
                    }
                }

                ProgressView(value: Double(remainingSeconds), total: 30)
                    .tint(remainingSeconds < 10 ? .red : .blue)

                Text("\(remainingSeconds)s remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .onAppear(perform: updateCode)
        .onReceive(timer) { _ in
            updateCode()
        }
    }

    private func updateCode() {
        guard let secret = entry.totpSecret,
              let totpCode = TOTPService.shared.generateCode(secret: secret) else {
            return
        }
        code = totpCode.code
        remainingSeconds = totpCode.remainingSeconds
    }

    private func formattedCode(_ code: String) -> String {
        let index = code.index(code.startIndex, offsetBy: 3)
        return "\(code[..<index]) \(code[index...])"
    }
}

struct TOTPCodeView: View {
    let secret: String
    @State private var code: String?
    @State private var remainingSeconds = 30

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        if let code = code {
            VStack(spacing: 12) {
                HStack {
                    Text(formattedCode(code))
                        .font(.system(.title, design: .monospaced))
                        .fontWeight(.semibold)

                    Spacer()

                    Button(action: {
                        UIPasteboard.general.string = code
                    }) {
                        Image(systemName: "doc.on.doc")
                            .imageScale(.large)
                    }
                }

                ProgressView(value: Double(remainingSeconds), total: 30)
                    .tint(remainingSeconds < 10 ? .red : .blue)

                Text("\(remainingSeconds)s remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .onAppear(perform: updateCode)
            .onReceive(timer) { _ in
                updateCode()
            }
        }
    }

    private func updateCode() {
        guard let totpCode = TOTPService.shared.generateCode(secret: secret) else {
            return
        }
        code = totpCode.code
        remainingSeconds = totpCode.remainingSeconds
    }

    private func formattedCode(_ code: String) -> String {
        let index = code.index(code.startIndex, offsetBy: 3)
        return "\(code[..<index]) \(code[index...])"
    }
}

import UIKit
