//
//  CredentialProviderViewController.swift
//  AutoFillExtension
//
//  Password AutoFill Credential Provider Extension
//

import AuthenticationServices
import SwiftUI

class CredentialProviderViewController: ASCredentialProviderViewController {

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        // Show list of credentials for the requested service
        let hostingController = UIHostingController(rootView: CredentialListView(serviceIdentifiers: serviceIdentifiers))
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.frame = view.bounds
        hostingController.didMove(toParent: self)
    }

    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        // Attempt to provide credential without user interaction
        // This requires biometric unlock
        Task {
            do {
                try await BiometricService.shared.authenticate()
                let credential = try await getCredential(for: credentialIdentity)
                extensionContext.completeRequest(withSelectedCredential: credential)
            } catch {
                extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userInteractionRequired.rawValue))
            }
        }
    }

    override func prepareInterfaceToProvideCredential(for credentialIdentity: ASPasswordCredentialIdentity) {
        // Show unlock screen, then provide credential
        let hostingController = UIHostingController(rootView: AutoFillUnlockView(credentialIdentity: credentialIdentity))
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.frame = view.bounds
        hostingController.didMove(toParent: self)
    }

    private func getCredential(for identity: ASPasswordCredentialIdentity) async throws -> ASPasswordCredential {
        // Load vault and find matching credential
        // This is a simplified example
        guard let recordIdentifier = identity.recordIdentifier else {
            throw NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.credentialIdentityNotFound.rawValue)
        }

        // In production, load from shared keychain using app groups
        let password = "example_password" // Load from vault

        return ASPasswordCredential(user: identity.user, password: password)
    }
}

// MARK: - SwiftUI Views

struct CredentialListView: View {
    let serviceIdentifiers: [ASCredentialServiceIdentifier]

    var body: some View {
        NavigationView {
            List {
                Text("Select credential for \(serviceIdentifiers.first?.identifier ?? "service")")
            }
            .navigationTitle("SecureVault")
        }
    }
}

struct AutoFillUnlockView: View {
    let credentialIdentity: ASPasswordCredentialIdentity

    var body: some View {
        VStack {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
            Text("Unlock SecureVault")
                .font(.title)
            Text("Authenticate to access \(credentialIdentity.user)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}
