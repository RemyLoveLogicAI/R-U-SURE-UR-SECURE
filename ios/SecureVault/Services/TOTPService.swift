//
//  TOTPService.swift
//  SecureVault
//
//  Time-based One-Time Password (TOTP) implementation
//  RFC 6238 compliant
//

import Foundation
import CryptoKit

final class TOTPService {
    static let shared = TOTPService()

    private let timeStep: TimeInterval = 30
    private let digits = 6

    private init() {}

    // MARK: - TOTP Generation

    /// Generate TOTP code from secret
    func generateCode(secret: String) -> TOTPCode? {
        guard let secretData = base32Decode(secret) else {
            return nil
        }

        let counter = UInt64(Date().timeIntervalSince1970 / timeStep)
        let code = generateHOTP(secret: secretData, counter: counter)

        let remainingTime = Int(timeStep - Date().timeIntervalSince1970.truncatingRemainder(dividingBy: timeStep))

        return TOTPCode(code: code, remainingSeconds: remainingTime)
    }

    /// Get time remaining until next code
    func getRemainingSeconds() -> Int {
        return Int(timeStep - Date().timeIntervalSince1970.truncatingRemainder(dividingBy: timeStep))
    }

    // MARK: - URI Parsing

    /// Parse otpauth:// URI
    func parseOTPAuthURI(_ uri: String) -> OTPAuthData? {
        guard uri.hasPrefix("otpauth://totp/"),
              let url = URL(string: uri),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let secret = components.queryItems?.first(where: { $0.name == "secret" })?.value else {
            return nil
        }

        // Extract issuer and account from path
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let parts = path.components(separatedBy: ":")

        let issuer: String
        let account: String

        if parts.count >= 2 {
            issuer = parts[0]
            account = parts[1]
        } else {
            issuer = parts.first ?? "Unknown"
            account = ""
        }

        return OTPAuthData(
            secret: secret,
            issuer: issuer.removingPercentEncoding ?? issuer,
            account: account.removingPercentEncoding ?? account
        )
    }

    // MARK: - Private Helpers

    private func generateHOTP(secret: Data, counter: UInt64) -> String {
        var counterBigEndian = counter.bigEndian
        let counterData = Data(bytes: &counterBigEndian, count: MemoryLayout<UInt64>.size)

        let key = SymmetricKey(data: secret)
        let hmac = HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: key)

        let hmacData = Data(hmac)
        let offset = Int(hmacData[hmacData.count - 1] & 0x0f)

        let truncatedHash = hmacData.subdata(in: offset..<offset + 4)
        let value = truncatedHash.withUnsafeBytes { $0.load(as: UInt32.self) }

        let code = (Int(value.bigEndian) & 0x7FFFFFFF) % Int(pow(10, Double(digits)))

        return String(format: "%0\(digits)d", code)
    }

    private func base32Decode(_ string: String) -> Data? {
        let base32Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        var bits = ""

        let cleanString = string.uppercased().replacingOccurrences(of: "=", with: "")

        for char in cleanString {
            guard let index = base32Alphabet.firstIndex(of: char) else {
                continue
            }
            let value = base32Alphabet.distance(from: base32Alphabet.startIndex, to: index)
            bits += String(value, radix: 2).leftPadding(toLength: 5, withPad: "0")
        }

        var data = Data()
        var index = bits.startIndex

        while bits.distance(from: index, to: bits.endIndex) >= 8 {
            let byteString = String(bits[index..<bits.index(index, offsetBy: 8)])
            guard let byte = UInt8(byteString, radix: 2) else {
                return nil
            }
            data.append(byte)
            index = bits.index(index, offsetBy: 8)
        }

        return data
    }
}

// MARK: - Supporting Types

struct TOTPCode {
    let code: String
    let remainingSeconds: Int

    var progress: Double {
        return Double(remainingSeconds) / 30.0
    }
}

struct OTPAuthData {
    let secret: String
    let issuer: String
    let account: String
}

// MARK: - String Extension

extension String {
    func leftPadding(toLength: Int, withPad character: Character) -> String {
        let stringLength = self.count
        if stringLength < toLength {
            return String(repeatElement(character, count: toLength - stringLength)) + self
        } else {
            return self
        }
    }
}
