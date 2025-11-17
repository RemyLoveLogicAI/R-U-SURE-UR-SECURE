/**
 * TOTP (Time-based One-Time Password) implementation
 * RFC 6238 compliant
 */

import { base32Decode } from './crypto';

/**
 * Generate a TOTP code from a secret
 */
export async function generateTOTP(secret: string): Promise<string> {
  try {
    const decodedKey = base32Decode(secret);
    // Create a new Uint8Array to ensure proper typing for Web Crypto API
    const key = new Uint8Array(decodedKey);
    const epoch = Math.floor(Date.now() / 1000);
    const counter = Math.floor(epoch / 30);
    const buffer = new ArrayBuffer(8);
    const view = new DataView(buffer);
    view.setBigUint64(0, BigInt(counter), false);

    const cryptoKey = await crypto.subtle.importKey(
      'raw',
      key,
      { name: 'HMAC', hash: 'SHA-1' },
      false,
      ['sign']
    );

    const signature = await crypto.subtle.sign('HMAC', cryptoKey, buffer);
    const bytes = new Uint8Array(signature);
    const offset = bytes[bytes.length - 1] & 0x0f;
    const code =
      (((bytes[offset] & 0x7f) << 24) |
        ((bytes[offset + 1] & 0xff) << 16) |
        ((bytes[offset + 2] & 0xff) << 8) |
        (bytes[offset + 3] & 0xff)) %
      1000000;

    return code.toString().padStart(6, '0');
  } catch (error) {
    console.error('TOTP generation failed:', error);
    return '------';
  }
}

/**
 * Get seconds remaining until next TOTP code
 */
export function getTOTPTimeRemaining(): number {
  return 30 - (Math.floor(Date.now() / 1000) % 30);
}

/**
 * Parse otpauth:// URI from QR code
 */
export interface OTPAuthData {
  secret: string;
  issuer: string;
  account: string;
}

export function parseOTPAuthURI(uri: string): OTPAuthData | null {
  try {
    if (!uri.startsWith('otpauth://totp/')) {
      return null;
    }

    const url = new URL(uri);
    const secret = url.searchParams.get('secret');
    if (!secret) return null;

    const pathParts = url.pathname.split('/');
    const label = decodeURIComponent(pathParts[pathParts.length - 1]);
    const [issuer, account] = label.includes(':') ? label.split(':', 2) : [label, ''];

    return {
      secret,
      issuer: issuer || 'Unknown Service',
      account: account || '',
    };
  } catch (error) {
    console.error('Failed to parse OTP URI:', error);
    return null;
  }
}
