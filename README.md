# 🔒 SecureVault - R U SURE UR SECURE?

A **production-ready password manager** with military-grade encryption, 2FA support, and API key management.

Available in **two versions:**
- 🌐 **[Web App](.)** - React + TypeScript for browser use
- 📱 **[iOS Native App](ios/)** - Swift + SwiftUI to replace Apple Passwords

## 🎯 Purpose

This project demonstrates **secure application development** by addressing common security vulnerabilities found in password managers. Built for the **R-U-SURE-UR-SECURE** repository to showcase proper security practices across platforms.

## ✅ Security Features

### **Critical Fixes Implemented**

#### 1. **Secure Password Input (Fixed V1)**
- ❌ **Before**: Used insecure `prompt()` function
- ✅ **After**: Custom password modal with:
  - Password strength indicator
  - Confirmation validation
  - No browser history exposure
  - Auto-clearing from memory

#### 2. **Secure Clipboard Operations (Fixed V2)**
- ❌ **Before**: Passwords stayed in clipboard indefinitely
- ✅ **After**: Auto-clear clipboard after 30 seconds
  - Visual feedback with toast notifications
  - Manual clear option
  - Error handling

#### 3. **Encrypted Persistence (Fixed V3)**
- ❌ **Before**: Data lost on page refresh
- ✅ **After**: Encrypted localStorage with:
  - AES-256-GCM encryption
  - PBKDF2 key derivation (100k iterations)
  - Auto-save functionality
  - Version management

#### 4. **Master Password & Auto-Lock (Fixed V4)**
- ❌ **Before**: No authentication, always accessible
- ✅ **After**: Master password protection with:
  - Auto-lock after 5 minutes of inactivity
  - Manual lock button
  - Activity tracking
  - Secure unlock flow

#### 5. **Secure Export/Import (Fixed V5)**
- ❌ **Before**:
  - Used `prompt()` for encryption password
  - No password confirmation
  - Weak filename reveals vault purpose
- ✅ **After**:
  - Secure password modal with confirmation
  - Password strength validation
  - Timestamped filenames
  - Proper error handling

#### 6. **Bundled Dependencies (Fixed V6)**
- ❌ **Before**: CDN-loaded jsQR (supply chain risk)
- ✅ **After**: NPM-installed, verified packages

#### 7. **Comprehensive Error Handling**
- No information leakage in error messages
- Graceful failure modes
- User-friendly error notifications

## 🔐 Encryption Details

```
Algorithm: AES-256-GCM (Authenticated Encryption)
Key Derivation: PBKDF2-SHA256
Iterations: 100,000
Salt: Random 16 bytes per export
IV: Random 12 bytes per export
Password Generator: Crypto.getRandomValues()
TOTP: RFC 6238 compliant (SHA-1 HMAC)
```

## 🚀 Quick Start

### Installation

```bash
npm install
```

### Development

```bash
npm run dev
```

### Build

```bash
npm run build
```

### Preview Production Build

```bash
npm run preview
```

## 📋 Features

### Password Management
- ✅ Secure password storage
- ✅ Strong password generation (16 chars, mixed case, numbers, symbols)
- ✅ Username/email storage
- ✅ Copy to clipboard with auto-clear

### 2FA (Two-Factor Authentication)
- ✅ TOTP code generation
- ✅ QR code scanning
- ✅ Secret key management
- ✅ 30-second countdown timer
- ✅ RFC 6238 compliant

### API Key Management
- ✅ Store API keys for 30+ popular providers
- ✅ Direct links to provider dashboards
- ✅ Custom provider support
- ✅ Notes field for metadata

### Security
- ✅ Client-side only (no server)
- ✅ AES-256-GCM encryption
- ✅ Master password protection
- ✅ Auto-lock after inactivity
- ✅ Encrypted localStorage backup
- ✅ Encrypted export/import
- ✅ Memory clearing after use

## 🎨 Supported API Providers

Pre-configured with direct links to key generation for:

- **AI**: OpenAI, Anthropic, Google Cloud, Cohere, Hugging Face, Replicate, ElevenLabs, Stability AI
- **Cloud**: AWS, Azure, GCP, DigitalOcean, Heroku
- **Payments**: Stripe, PayPal
- **Communications**: Twilio, SendGrid, Slack, Discord, Telegram
- **Development**: GitHub, GitLab, Vercel, Netlify, Cloudflare
- **Databases**: MongoDB Atlas, Supabase, Firebase, Pinecone
- **Maps**: Mapbox, Google Maps

Plus support for custom providers!

## 🔍 Security Audit Checklist

- [x] No plaintext password storage
- [x] No insecure `prompt()` usage
- [x] Auto-clearing clipboard
- [x] Encrypted persistence
- [x] Master password authentication
- [x] Auto-lock mechanism
- [x] Password strength validation
- [x] Secure export with confirmation
- [x] No CDN dependencies
- [x] Proper error handling
- [x] No information leakage
- [x] Memory clearing
- [x] TOTP compliance
- [x] Supply chain security

## ⚠️ Security Considerations

### ✅ What This Protects Against
- Casual snooping
- Data breaches of service providers (passwords never sent to servers)
- Physical theft (with auto-lock enabled)
- Weak passwords (password generator)
- Shoulder surfing (password masking)

### ❌ What This CANNOT Protect Against
- Keyloggers on compromised systems
- Browser extensions with malicious intent
- XSS attacks (if hosted on compromised domain)
- Physical access while vault is unlocked
- Memory dumps from malware
- Weak master passwords

### 🎯 Best Practices
1. **Use a strong master password** (12+ characters, mixed case, numbers, symbols)
2. **Lock your vault** when stepping away
3. **Export backups regularly** to encrypted files
4. **Use HTTPS** when hosting
5. **Keep browser updated** for latest security patches
6. **Don't use on shared/untrusted devices**

## 📱 Browser Compatibility

- ✅ Chrome 60+
- ✅ Firefox 57+
- ✅ Safari 11+
- ✅ Edge 79+

(Requires Web Crypto API support)

## 🏗️ Project Structure

```
src/
├── components/
│   ├── SecureVault.tsx      # Main vault component
│   ├── PasswordModal.tsx    # Secure password input
│   └── Toast.tsx            # Notification system
├── utils/
│   ├── crypto.ts            # Encryption/decryption
│   ├── totp.ts              # 2FA code generation
│   ├── secureClipboard.ts   # Clipboard management
│   └── storage.ts           # Encrypted localStorage
├── data/
│   └── apiProviders.ts      # API provider links
└── App.tsx                  # Root component
```

## 🧪 Testing

```bash
# Build test
npm run build

# Check for TypeScript errors
npm run build -- --noEmit

# Preview production build
npm run preview
```

## 📦 Deployment

### Static Hosting (Vercel, Netlify, GitHub Pages)

```bash
npm run build
# Deploy the 'dist' folder
```

### Environment Variables
None required! Everything is client-side.

## 🔬 Educational Value

This project demonstrates:

1. **Web Crypto API** usage
2. **PBKDF2** key derivation
3. **AES-GCM** authenticated encryption
4. **TOTP** implementation
5. **QR code** parsing
6. **LocalStorage** encryption
7. **React** state management
8. **TypeScript** type safety
9. **Security** best practices
10. **UX** for security features

## 🐛 Known Limitations

1. **No cloud sync** - Data stored locally only
2. **No password sharing** - Single-user design
3. **No password history** - No version tracking
4. **No biometric auth** - Password-only
5. **No mobile app** - Web-only
6. **No breach checking** - No integration with HaveIBeenPwned

## 🛣️ Future Enhancements

- [ ] Browser extension
- [ ] WebAuthn/biometric support
- [ ] Password breach checking
- [ ] Secure notes
- [ ] File attachments (encrypted)
- [ ] Password history
- [ ] Multi-device sync (E2E encrypted)
- [ ] Password sharing (encrypted)
- [ ] Mobile apps

## 📄 License

MIT License - See LICENSE file for details

## 🙏 Acknowledgments

- Web Crypto API for encryption primitives
- jsQR for QR code scanning
- Lucide React for icons
- Tailwind CSS for styling
- Vite for blazing-fast development

## ⚖️ Disclaimer

This is an educational project demonstrating security best practices. While it implements proper encryption and security measures, use at your own risk. For critical passwords, consider established solutions like:

- 1Password
- Bitwarden
- KeePass
- LastPass

---

**Built with ❤️ for security education**

**Repository**: R-U-SURE-UR-SECURE
**Focus**: Demonstrating secure web application development
