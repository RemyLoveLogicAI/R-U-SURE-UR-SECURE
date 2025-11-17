/**
 * Cryptographic utilities using Web Crypto API
 * AES-256-GCM with PBKDF2 key derivation
 */

export interface EncryptedData {
  salt: number[];
  iv: number[];
  data: number[];
  version: number; // For future migrations
}

const PBKDF2_ITERATIONS = 100000;
const AES_KEY_LENGTH = 256;
const SALT_LENGTH = 16;
const IV_LENGTH = 12;
const CURRENT_VERSION = 1;

/**
 * Encrypt data with a password
 */
export async function encryptData(data: any, password: string): Promise<EncryptedData> {
  try {
    const encoder = new TextEncoder();
    const salt = crypto.getRandomValues(new Uint8Array(SALT_LENGTH));

    // Derive key from password
    const keyMaterial = await crypto.subtle.importKey(
      'raw',
      encoder.encode(password),
      'PBKDF2',
      false,
      ['deriveBits', 'deriveKey']
    );

    const key = await crypto.subtle.deriveKey(
      {
        name: 'PBKDF2',
        salt,
        iterations: PBKDF2_ITERATIONS,
        hash: 'SHA-256',
      },
      keyMaterial,
      { name: 'AES-GCM', length: AES_KEY_LENGTH },
      false,
      ['encrypt']
    );

    // Encrypt data
    const iv = crypto.getRandomValues(new Uint8Array(IV_LENGTH));
    const encrypted = await crypto.subtle.encrypt(
      { name: 'AES-GCM', iv },
      key,
      encoder.encode(JSON.stringify(data))
    );

    return {
      salt: Array.from(salt),
      iv: Array.from(iv),
      data: Array.from(new Uint8Array(encrypted)),
      version: CURRENT_VERSION,
    };
  } catch (error) {
    throw new Error('Encryption failed: ' + (error instanceof Error ? error.message : 'Unknown error'));
  }
}

/**
 * Decrypt data with a password
 */
export async function decryptData(encryptedObj: EncryptedData, password: string): Promise<any> {
  try {
    const encoder = new TextEncoder();
    const decoder = new TextDecoder();

    // Check version compatibility
    if (encryptedObj.version !== CURRENT_VERSION) {
      throw new Error(`Unsupported vault version: ${encryptedObj.version}`);
    }

    // Derive key from password
    const keyMaterial = await crypto.subtle.importKey(
      'raw',
      encoder.encode(password),
      'PBKDF2',
      false,
      ['deriveBits', 'deriveKey']
    );

    const key = await crypto.subtle.deriveKey(
      {
        name: 'PBKDF2',
        salt: new Uint8Array(encryptedObj.salt),
        iterations: PBKDF2_ITERATIONS,
        hash: 'SHA-256',
      },
      keyMaterial,
      { name: 'AES-GCM', length: AES_KEY_LENGTH },
      false,
      ['decrypt']
    );

    // Decrypt data
    const decrypted = await crypto.subtle.decrypt(
      { name: 'AES-GCM', iv: new Uint8Array(encryptedObj.iv) },
      key,
      new Uint8Array(encryptedObj.data)
    );

    return JSON.parse(decoder.decode(decrypted));
  } catch (error) {
    // Don't leak information about why decryption failed
    if (error instanceof Error && error.message.includes('version')) {
      throw error;
    }
    throw new Error('Decryption failed. Incorrect password or corrupted data.');
  }
}

/**
 * Generate a secure random password
 */
export function generatePassword(length: number = 16): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*';
  const array = new Uint8Array(length);
  crypto.getRandomValues(array);
  return Array.from(array, (byte) => chars[byte % chars.length]).join('');
}

/**
 * Generate a secure TOTP secret (base32)
 */
const base32Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

export function generateSecret(): string {
  const buffer = new Uint8Array(20);
  crypto.getRandomValues(buffer);
  return base32Encode(buffer);
}

export function base32Encode(buffer: Uint8Array): string {
  let bits = '';
  const bytes = new Uint8Array(buffer);
  for (let i = 0; i < bytes.length; i++) {
    bits += bytes[i].toString(2).padStart(8, '0');
  }
  let result = '';
  for (let i = 0; i + 5 <= bits.length; i += 5) {
    result += base32Chars[parseInt(bits.substr(i, 5), 2)];
  }
  while (result.length % 8 !== 0) result += '=';
  return result;
}

export function base32Decode(base32: string): Uint8Array {
  const cleanedBase32 = base32.replace(/=+$/, '').toUpperCase();
  let bits = '';
  for (let i = 0; i < cleanedBase32.length; i++) {
    const val = base32Chars.indexOf(cleanedBase32[i]);
    if (val === -1) continue;
    bits += val.toString(2).padStart(5, '0');
  }
  const bytes = new Uint8Array(Math.floor(bits.length / 8));
  for (let i = 0; i < bytes.length; i++) {
    bytes[i] = parseInt(bits.substr(i * 8, 8), 2);
  }
  return bytes;
}
