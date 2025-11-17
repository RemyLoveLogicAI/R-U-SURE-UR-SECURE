/**
 * Encrypted localStorage persistence
 */

import { encryptData, decryptData, type EncryptedData } from './crypto';

const STORAGE_KEY = 'secure_vault_encrypted';
const LAST_ACTIVITY_KEY = 'secure_vault_last_activity';
const AUTO_LOCK_MINUTES = 5;

export interface VaultData {
  entries: any[];
  apiKeys: any[];
}

/**
 * Save encrypted vault data to localStorage
 */
export async function saveVault(data: VaultData, password: string): Promise<void> {
  try {
    const encrypted = await encryptData(data, password);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(encrypted));
    updateLastActivity();
  } catch (error) {
    throw new Error('Failed to save vault: ' + (error instanceof Error ? error.message : 'Unknown error'));
  }
}

/**
 * Load and decrypt vault data from localStorage
 */
export async function loadVault(password: string): Promise<VaultData | null> {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (!stored) return null;

    const encrypted: EncryptedData = JSON.parse(stored);
    const decrypted = await decryptData(encrypted, password);
    updateLastActivity();
    return decrypted;
  } catch (error) {
    throw new Error('Failed to load vault: ' + (error instanceof Error ? error.message : 'Unknown error'));
  }
}

/**
 * Check if a vault exists in storage
 */
export function hasStoredVault(): boolean {
  return localStorage.getItem(STORAGE_KEY) !== null;
}

/**
 * Clear vault from storage
 */
export function clearVault(): void {
  localStorage.removeItem(STORAGE_KEY);
  localStorage.removeItem(LAST_ACTIVITY_KEY);
}

/**
 * Update last activity timestamp
 */
export function updateLastActivity(): void {
  localStorage.setItem(LAST_ACTIVITY_KEY, Date.now().toString());
}

/**
 * Check if vault should be auto-locked
 */
export function shouldAutoLock(): boolean {
  const lastActivity = localStorage.getItem(LAST_ACTIVITY_KEY);
  if (!lastActivity) return true;

  const minutesSinceActivity = (Date.now() - parseInt(lastActivity)) / 1000 / 60;
  return minutesSinceActivity >= AUTO_LOCK_MINUTES;
}

/**
 * Export vault to encrypted file
 */
export async function exportVaultToFile(data: VaultData, password: string): Promise<void> {
  try {
    const encrypted = await encryptData(data, password);
    const blob = new Blob([JSON.stringify(encrypted, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `secure-vault-${new Date().toISOString().split('T')[0]}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  } catch (error) {
    throw new Error('Failed to export vault: ' + (error instanceof Error ? error.message : 'Unknown error'));
  }
}

/**
 * Import vault from encrypted file
 */
export async function importVaultFromFile(file: File, password: string): Promise<VaultData> {
  try {
    const text = await file.text();
    const encrypted: EncryptedData = JSON.parse(text);
    const decrypted = await decryptData(encrypted, password);
    return decrypted;
  } catch (error) {
    throw new Error('Failed to import vault: ' + (error instanceof Error ? error.message : 'Unknown error'));
  }
}
