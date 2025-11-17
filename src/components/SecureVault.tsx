import { useState, useEffect, useRef } from 'react';
import {
  Eye,
  EyeOff,
  Key,
  Shield,
  Download,
  Plus,
  Trash2,
  Copy,
  RefreshCw,
  Upload,
  Camera,
  ExternalLink,
  Lock,
  Save,
} from 'lucide-react';
import jsQR from 'jsqr';

import PasswordModal from './PasswordModal';
import { ToastContainer, type ToastType } from './Toast';
import { generatePassword, generateSecret } from '../utils/crypto';
import { generateTOTP, getTOTPTimeRemaining, parseOTPAuthURI } from '../utils/totp';
import { secureCopyToClipboard } from '../utils/secureClipboard';
import {
  saveVault,
  loadVault,
  hasStoredVault,
  clearVault,
  exportVaultToFile,
  importVaultFromFile,
  updateLastActivity,
  shouldAutoLock,
} from '../utils/storage';
import { API_PROVIDERS } from '../data/apiProviders';

interface Entry {
  id: number;
  name: string;
  username: string;
  password: string;
  secret: string;
}

interface ApiKey {
  id: number;
  provider: string;
  providerUrl: string;
  apiKey: string;
  notes: string;
}

interface Toast {
  id: string;
  message: string;
  type: ToastType;
}

export default function SecureVault() {
  const [isLocked, setIsLocked] = useState(true);
  const [masterPassword, setMasterPassword] = useState('');
  const [entries, setEntries] = useState<Entry[]>([]);
  const [apiKeys, setApiKeys] = useState<ApiKey[]>([]);
  const [showPasswords, setShowPasswords] = useState<Record<number, boolean>>({});
  const [showSecrets, setShowSecrets] = useState<Record<number, boolean>>({});
  const [showApiKeys, setShowApiKeys] = useState<Record<number, boolean>>({});
  const [totpCodes, setTotpCodes] = useState<Record<number, string>>({});
  const [newEntry, setNewEntry] = useState<Omit<Entry, 'id'>>({
    name: '',
    username: '',
    password: '',
    secret: '',
  });
  const [newApiKey, setNewApiKey] = useState<Omit<ApiKey, 'id' | 'providerUrl'>>({
    provider: '',
    apiKey: '',
    notes: '',
  });
  const [showCustomProvider, setShowCustomProvider] = useState(false);
  const [customProvider, setCustomProvider] = useState('');
  const [toasts, setToasts] = useState<Toast[]>([]);
  const [passwordModal, setPasswordModal] = useState<{
    isOpen: boolean;
    title: string;
    onSubmit: (password: string) => void;
    requireConfirmation?: boolean;
    showStrength?: boolean;
  }>({
    isOpen: false,
    title: '',
    onSubmit: () => {},
  });

  const canvasRef = useRef<HTMLCanvasElement>(null);
  const autoLockTimerRef = useRef<number | null>(null);

  // Auto-lock functionality
  useEffect(() => {
    if (!isLocked) {
      const resetAutoLock = () => {
        updateLastActivity();
        if (autoLockTimerRef.current) {
          clearTimeout(autoLockTimerRef.current);
        }
        autoLockTimerRef.current = setTimeout(() => {
          if (shouldAutoLock()) {
            handleLock();
            showToast('Vault locked due to inactivity', 'info');
          }
        }, 5 * 60 * 1000); // 5 minutes
      };

      // Track user activity
      window.addEventListener('mousemove', resetAutoLock);
      window.addEventListener('keydown', resetAutoLock);
      window.addEventListener('click', resetAutoLock);

      resetAutoLock();

      return () => {
        window.removeEventListener('mousemove', resetAutoLock);
        window.removeEventListener('keydown', resetAutoLock);
        window.removeEventListener('click', resetAutoLock);
        if (autoLockTimerRef.current) {
          clearTimeout(autoLockTimerRef.current);
        }
      };
    }
  }, [isLocked]);

  // TOTP code generation
  useEffect(() => {
    if (isLocked) return;

    const interval = setInterval(() => {
      entries.forEach(async (entry, idx) => {
        if (entry.secret) {
          const code = await generateTOTP(entry.secret);
          setTotpCodes((prev) => ({ ...prev, [idx]: code }));
        }
      });
    }, 1000);

    return () => clearInterval(interval);
  }, [entries, isLocked]);

  // Auto-save to localStorage
  useEffect(() => {
    if (!isLocked && masterPassword) {
      const saveData = async () => {
        try {
          await saveVault({ entries, apiKeys }, masterPassword);
        } catch (error) {
          console.error('Auto-save failed:', error);
        }
      };
      const debounce = setTimeout(saveData, 1000);
      return () => clearTimeout(debounce);
    }
  }, [entries, apiKeys, masterPassword, isLocked]);

  const showToast = (message: string, type: ToastType) => {
    const id = Date.now().toString();
    setToasts((prev) => [...prev, { id, message, type }]);
  };

  const removeToast = (id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  };

  const handleUnlock = async (password: string) => {
    try {
      if (hasStoredVault()) {
        const data = await loadVault(password);
        if (data) {
          setEntries(data.entries || []);
          setApiKeys(data.apiKeys || []);
          setMasterPassword(password);
          setIsLocked(false);
          showToast('Vault unlocked successfully', 'success');
        }
      } else {
        // First time setup - create new vault
        setMasterPassword(password);
        setIsLocked(false);
        showToast('New vault created successfully', 'success');
      }
    } catch (error) {
      showToast(error instanceof Error ? error.message : 'Failed to unlock vault', 'error');
    }
    setPasswordModal({ ...passwordModal, isOpen: false });
  };

  const handleLock = () => {
    setIsLocked(true);
    setMasterPassword('');
    setEntries([]);
    setApiKeys([]);
    setShowPasswords({});
    setShowSecrets({});
    setShowApiKeys({});
    setTotpCodes({});
  };

  const handleCopy = async (text: string, label: string) => {
    const success = await secureCopyToClipboard(text, {
      autoClearSeconds: 30,
      onCopied: () => showToast(`${label} copied! Will auto-clear in 30s`, 'success'),
      onCleared: () => showToast('Clipboard cleared', 'info'),
      onError: (error) => showToast('Failed to copy: ' + error.message, 'error'),
    });

    if (!success) {
      showToast('Failed to copy to clipboard', 'error');
    }
  };

  const addEntry = () => {
    if (!newEntry.name) {
      showToast('Service name is required', 'error');
      return;
    }
    setEntries([...entries, { ...newEntry, id: Date.now() }]);
    setNewEntry({ name: '', username: '', password: '', secret: '' });
    showToast('Entry added successfully', 'success');
  };

  const addApiKey = () => {
    const provider = showCustomProvider ? customProvider : newApiKey.provider;
    if (!provider || !newApiKey.apiKey) {
      showToast('Provider and API key are required', 'error');
      return;
    }

    const providerUrl =
      API_PROVIDERS[provider] ||
      `https://www.google.com/search?q=${encodeURIComponent(provider + ' API key generation')}`;

    setApiKeys([
      ...apiKeys,
      {
        ...newApiKey,
        provider,
        providerUrl,
        id: Date.now(),
      },
    ]);
    setNewApiKey({ provider: '', apiKey: '', notes: '' });
    setCustomProvider('');
    setShowCustomProvider(false);
    showToast('API key added successfully', 'success');
  };

  const deleteEntry = (idx: number) => {
    setEntries(entries.filter((_, i) => i !== idx));
    const newShow = { ...showPasswords };
    delete newShow[idx];
    setShowPasswords(newShow);
    showToast('Entry deleted', 'info');
  };

  const deleteApiKey = (idx: number) => {
    setApiKeys(apiKeys.filter((_, i) => i !== idx));
    const newShow = { ...showApiKeys };
    delete newShow[idx];
    setShowApiKeys(newShow);
    showToast('API key deleted', 'info');
  };

  const handleExport = () => {
    setPasswordModal({
      isOpen: true,
      title: 'Export Vault',
      requireConfirmation: true,
      showStrength: true,
      onSubmit: async (password) => {
        try {
          await exportVaultToFile({ entries, apiKeys }, password);
          showToast('Vault exported successfully', 'success');
        } catch (error) {
          showToast(error instanceof Error ? error.message : 'Export failed', 'error');
        }
        setPasswordModal({ ...passwordModal, isOpen: false });
      },
    });
  };

  const handleImport = () => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.json';
    input.onchange = async (e) => {
      const file = (e.target as HTMLInputElement).files?.[0];
      if (!file) return;

      setPasswordModal({
        isOpen: true,
        title: 'Import Vault - Enter Password',
        requireConfirmation: false,
        showStrength: false,
        onSubmit: async (password) => {
          try {
            const data = await importVaultFromFile(file, password);
            setEntries(data.entries || []);
            setApiKeys(data.apiKeys || []);
            showToast('Vault imported successfully', 'success');
          } catch (error) {
            showToast(error instanceof Error ? error.message : 'Import failed', 'error');
          }
          setPasswordModal({ ...passwordModal, isOpen: false });
        },
      });
    };
    input.click();
  };

  const scanQRCode = () => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    input.onchange = async (e) => {
      const file = (e.target as HTMLInputElement).files?.[0];
      if (!file) return;

      const img = new Image();
      const reader = new FileReader();

      reader.onload = (event) => {
        img.onload = () => {
          const canvas = canvasRef.current;
          if (!canvas) return;

          const ctx = canvas.getContext('2d');
          if (!ctx) return;

          canvas.width = img.width;
          canvas.height = img.height;
          ctx.drawImage(img, 0, 0);

          const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
          const code = jsQR(imageData.data, imageData.width, imageData.height);

          if (code && code.data) {
            const otpData = parseOTPAuthURI(code.data);
            if (otpData) {
              setNewEntry({
                ...newEntry,
                name: otpData.issuer,
                username: otpData.account,
                secret: otpData.secret,
              });
              showToast('QR code scanned successfully', 'success');
            } else {
              showToast('Not a valid 2FA QR code', 'error');
            }
          } else {
            showToast('No QR code found in image', 'error');
          }
        };
        img.src = event.target?.result as string;
      };
      reader.readAsDataURL(file);
    };
    input.click();
  };

  const timeLeft = getTOTPTimeRemaining();

  // Unlock screen
  if (isLocked) {
    return (
      <>
        <div className="min-h-screen bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900 flex items-center justify-center p-8">
          <div className="bg-slate-800/50 backdrop-blur rounded-lg p-8 border border-purple-500/20 max-w-md w-full">
            <div className="text-center mb-8">
              <Shield className="w-20 h-20 text-purple-400 mx-auto mb-4" />
              <h1 className="text-3xl font-bold text-white mb-2">SecureVault</h1>
              <p className="text-purple-300">Client-Side Password, 2FA & API Key Manager</p>
            </div>

            <button
              onClick={() =>
                setPasswordModal({
                  isOpen: true,
                  title: hasStoredVault() ? 'Unlock Vault' : 'Create Master Password',
                  requireConfirmation: !hasStoredVault(),
                  showStrength: !hasStoredVault(),
                  onSubmit: handleUnlock,
                })
              }
              className="w-full bg-purple-600 hover:bg-purple-700 text-white px-6 py-3 rounded-lg flex items-center justify-center gap-2 text-lg font-medium"
            >
              <Lock className="w-5 h-5" />
              {hasStoredVault() ? 'Unlock Vault' : 'Create New Vault'}
            </button>

            {hasStoredVault() && (
              <button
                onClick={() => {
                  if (confirm('Are you sure you want to delete your vault? This cannot be undone.')) {
                    clearVault();
                    showToast('Vault deleted', 'info');
                  }
                }}
                className="w-full mt-4 bg-red-600/20 hover:bg-red-600/30 text-red-400 px-6 py-2 rounded-lg text-sm border border-red-500/30"
              >
                Delete Vault
              </button>
            )}

            <div className="mt-8 text-center text-sm text-purple-300">
              <p>🔒 AES-256-GCM Encryption</p>
              <p>🔑 PBKDF2 100k Iterations</p>
              <p>💾 Auto-save to Local Storage</p>
              <p>⏰ Auto-lock after 5 min</p>
            </div>
          </div>
        </div>

        <PasswordModal {...passwordModal} onClose={() => setPasswordModal({ ...passwordModal, isOpen: false })} />
        <ToastContainer toasts={toasts} onRemove={removeToast} />
      </>
    );
  }

  // Main vault UI
  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900 p-8">
      <canvas ref={canvasRef} style={{ display: 'none' }} />

      <div className="max-w-6xl mx-auto">
        {/* Header */}
        <div className="flex items-center justify-between mb-8">
          <div className="flex items-center gap-3">
            <Shield className="w-12 h-12 text-purple-400" />
            <div>
              <h1 className="text-4xl font-bold text-white">SecureVault</h1>
              <p className="text-purple-300">Unlocked - Auto-lock in {Math.floor(5)} min of inactivity</p>
            </div>
          </div>
          <div className="flex gap-3">
            <button
              onClick={() => saveVault({ entries, apiKeys }, masterPassword)}
              className="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded flex items-center gap-2"
              title="Manual Save"
            >
              <Save className="w-4 h-4" />
              Save
            </button>
            <button
              onClick={handleLock}
              className="bg-purple-600 hover:bg-purple-700 text-white px-4 py-2 rounded flex items-center gap-2"
            >
              <Lock className="w-4 h-4" />
              Lock Vault
            </button>
          </div>
        </div>

        {/* Add New Entry */}
        <div className="bg-slate-800/50 backdrop-blur rounded-lg p-6 mb-6 border border-purple-500/20">
          <h2 className="text-xl font-semibold text-white mb-2">Add New Entry</h2>
          <p className="text-purple-300 text-sm mb-4">Generate passwords, scan 2FA QR codes, or enter manually</p>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <input
              type="text"
              placeholder="Service Name"
              value={newEntry.name}
              onChange={(e) => setNewEntry({ ...newEntry, name: e.target.value })}
              className="bg-slate-700 text-white px-4 py-2 rounded border border-slate-600 focus:border-purple-500 outline-none"
            />
            <input
              type="text"
              placeholder="Username/Email"
              value={newEntry.username}
              onChange={(e) => setNewEntry({ ...newEntry, username: e.target.value })}
              className="bg-slate-700 text-white px-4 py-2 rounded border border-slate-600 focus:border-purple-500 outline-none"
            />
            <div className="flex gap-2">
              <input
                type="password"
                placeholder="Password"
                value={newEntry.password}
                onChange={(e) => setNewEntry({ ...newEntry, password: e.target.value })}
                className="bg-slate-700 text-white px-4 py-2 rounded border border-slate-600 focus:border-purple-500 outline-none flex-1"
              />
              <button
                onClick={() => setNewEntry({ ...newEntry, password: generatePassword() })}
                className="bg-purple-600 hover:bg-purple-700 text-white px-4 py-2 rounded flex items-center gap-2"
                title="Generate Password"
              >
                <RefreshCw className="w-4 h-4" />
              </button>
              <button
                onClick={() => handleCopy(newEntry.password, 'Password')}
                className="bg-slate-600 hover:bg-slate-500 text-white px-4 py-2 rounded flex items-center gap-2"
                title="Copy Password"
                disabled={!newEntry.password}
              >
                <Copy className="w-4 h-4" />
              </button>
            </div>
            <div className="flex gap-2">
              <input
                type="password"
                placeholder="2FA Secret (Optional)"
                value={newEntry.secret}
                onChange={(e) => setNewEntry({ ...newEntry, secret: e.target.value.toUpperCase() })}
                className="bg-slate-700 text-white px-4 py-2 rounded border border-slate-600 focus:border-purple-500 outline-none flex-1"
              />
              <button
                onClick={scanQRCode}
                className="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded flex items-center gap-2"
                title="Scan QR Code"
              >
                <Camera className="w-4 h-4" />
              </button>
              <button
                onClick={() => setNewEntry({ ...newEntry, secret: generateSecret() })}
                className="bg-purple-600 hover:bg-purple-700 text-white px-4 py-2 rounded flex items-center gap-2"
                title="Generate Secret"
              >
                <Key className="w-4 h-4" />
              </button>
            </div>
          </div>
          <button
            onClick={addEntry}
            className="mt-4 bg-green-600 hover:bg-green-700 text-white px-6 py-2 rounded flex items-center gap-2 mx-auto"
          >
            <Plus className="w-4 h-4" />
            Add Entry
          </button>
        </div>

        {/* Add API Key */}
        <div className="bg-slate-800/50 backdrop-blur rounded-lg p-6 mb-6 border border-blue-500/20">
          <h2 className="text-xl font-semibold text-white mb-2">Add API Key</h2>
          <p className="text-blue-300 text-sm mb-4">Store API keys with direct links to provider dashboards</p>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="md:col-span-2">
              <div className="flex gap-2 mb-2">
                <button
                  onClick={() => setShowCustomProvider(false)}
                  className={`px-4 py-2 rounded ${
                    !showCustomProvider ? 'bg-blue-600 text-white' : 'bg-slate-700 text-slate-300'
                  }`}
                >
                  Popular Providers
                </button>
                <button
                  onClick={() => setShowCustomProvider(true)}
                  className={`px-4 py-2 rounded ${
                    showCustomProvider ? 'bg-blue-600 text-white' : 'bg-slate-700 text-slate-300'
                  }`}
                >
                  Custom Provider
                </button>
              </div>

              {!showCustomProvider ? (
                <select
                  value={newApiKey.provider}
                  onChange={(e) => setNewApiKey({ ...newApiKey, provider: e.target.value })}
                  className="bg-slate-700 text-white px-4 py-2 rounded border border-slate-600 focus:border-blue-500 outline-none w-full"
                >
                  <option value="">Select Provider</option>
                  {Object.keys(API_PROVIDERS).map((provider) => (
                    <option key={provider} value={provider}>
                      {provider}
                    </option>
                  ))}
                </select>
              ) : (
                <input
                  type="text"
                  placeholder="Enter provider name"
                  value={customProvider}
                  onChange={(e) => setCustomProvider(e.target.value)}
                  className="bg-slate-700 text-white px-4 py-2 rounded border border-slate-600 focus:border-blue-500 outline-none w-full"
                />
              )}
            </div>

            <div className="flex gap-2 md:col-span-2">
              <input
                type="password"
                placeholder="API Key"
                value={newApiKey.apiKey}
                onChange={(e) => setNewApiKey({ ...newApiKey, apiKey: e.target.value })}
                className="bg-slate-700 text-white px-4 py-2 rounded border border-slate-600 focus:border-blue-500 outline-none flex-1 font-mono"
              />
              <button
                onClick={() => handleCopy(newApiKey.apiKey, 'API Key')}
                className="bg-slate-600 hover:bg-slate-500 text-white px-4 py-2 rounded flex items-center gap-2"
                title="Copy API Key"
                disabled={!newApiKey.apiKey}
              >
                <Copy className="w-4 h-4" />
              </button>
            </div>

            <div className="md:col-span-2">
              <input
                type="text"
                placeholder="Notes (optional)"
                value={newApiKey.notes}
                onChange={(e) => setNewApiKey({ ...newApiKey, notes: e.target.value })}
                className="bg-slate-700 text-white px-4 py-2 rounded border border-slate-600 focus:border-blue-500 outline-none w-full"
              />
            </div>
          </div>
          <button
            onClick={addApiKey}
            className="mt-4 bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded flex items-center gap-2 mx-auto"
          >
            <Key className="w-4 h-4" />
            Add API Key
          </button>
        </div>

        {/* API Keys List */}
        {apiKeys.length > 0 && (
          <div className="mb-6">
            <h2 className="text-2xl font-bold text-blue-400 mb-4 flex items-center gap-2">
              <Key className="w-6 h-6" />
              API Keys ({apiKeys.length})
            </h2>
            <div className="space-y-4">
              {apiKeys.map((key, idx) => (
                <div key={key.id} className="bg-slate-800/50 backdrop-blur rounded-lg p-6 border border-blue-500/20">
                  <div className="flex items-start justify-between mb-4">
                    <div>
                      <h3 className="text-xl font-bold text-blue-400">{key.provider}</h3>
                      <a
                        href={key.providerUrl}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-blue-300 hover:text-blue-200 text-sm flex items-center gap-1 mt-1"
                      >
                        <ExternalLink className="w-3 h-3" />
                        Get/Manage Keys
                      </a>
                    </div>
                    <button onClick={() => deleteApiKey(idx)} className="text-red-400 hover:text-red-300">
                      <Trash2 className="w-5 h-5" />
                    </button>
                  </div>

                  <div className="grid grid-cols-1 gap-4">
                    <div>
                      <label className="text-sm text-blue-300 block mb-1">API Key</label>
                      <div className="flex gap-2">
                        <input
                          type={showApiKeys[idx] ? 'text' : 'password'}
                          value={key.apiKey}
                          readOnly
                          className="bg-slate-700 text-white px-4 py-2 rounded flex-1 font-mono text-sm"
                        />
                        <button
                          onClick={() => setShowApiKeys({ ...showApiKeys, [idx]: !showApiKeys[idx] })}
                          className="bg-slate-600 hover:bg-slate-500 text-white px-3 py-2 rounded"
                        >
                          {showApiKeys[idx] ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                        </button>
                        <button
                          onClick={() => handleCopy(key.apiKey, 'API Key')}
                          className="bg-blue-600 hover:bg-blue-700 text-white px-3 py-2 rounded"
                        >
                          <Copy className="w-4 h-4" />
                        </button>
                      </div>
                    </div>

                    {key.notes && (
                      <div>
                        <label className="text-sm text-blue-300 block mb-1">Notes</label>
                        <p className="text-slate-300 bg-slate-700 px-4 py-2 rounded">{key.notes}</p>
                      </div>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Password/2FA Entries */}
        {entries.length > 0 && (
          <div className="mb-6">
            <h2 className="text-2xl font-bold text-purple-400 mb-4 flex items-center gap-2">
              <Shield className="w-6 h-6" />
              Passwords & 2FA ({entries.length})
            </h2>
            <div className="space-y-4">
              {entries.map((entry, idx) => (
                <div
                  key={entry.id}
                  className="bg-slate-800/50 backdrop-blur rounded-lg p-6 border border-purple-500/20"
                >
                  <div className="flex items-start justify-between mb-4">
                    <h3 className="text-2xl font-bold text-purple-400">{entry.name}</h3>
                    <button onClick={() => deleteEntry(idx)} className="text-red-400 hover:text-red-300">
                      <Trash2 className="w-5 h-5" />
                    </button>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                      <label className="text-sm text-purple-300 block mb-1">Username</label>
                      <div className="flex gap-2">
                        <input
                          type="text"
                          value={entry.username}
                          readOnly
                          className="bg-slate-700 text-white px-4 py-2 rounded flex-1"
                        />
                        <button
                          onClick={() => handleCopy(entry.username, 'Username')}
                          className="bg-purple-600 hover:bg-purple-700 text-white px-3 py-2 rounded"
                        >
                          <Copy className="w-4 h-4" />
                        </button>
                      </div>
                    </div>

                    <div>
                      <label className="text-sm text-purple-300 block mb-1">Password</label>
                      <div className="flex gap-2">
                        <input
                          type={showPasswords[idx] ? 'text' : 'password'}
                          value={entry.password}
                          readOnly
                          className="bg-slate-700 text-white px-4 py-2 rounded flex-1 font-mono"
                        />
                        <button
                          onClick={() => setShowPasswords({ ...showPasswords, [idx]: !showPasswords[idx] })}
                          className="bg-slate-600 hover:bg-slate-500 text-white px-3 py-2 rounded"
                        >
                          {showPasswords[idx] ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                        </button>
                        <button
                          onClick={() => handleCopy(entry.password, 'Password')}
                          className="bg-purple-600 hover:bg-purple-700 text-white px-3 py-2 rounded"
                        >
                          <Copy className="w-4 h-4" />
                        </button>
                      </div>
                    </div>

                    {entry.secret && (
                      <>
                        <div>
                          <label className="text-sm text-purple-300 block mb-1">2FA Secret</label>
                          <div className="flex gap-2">
                            <input
                              type={showSecrets[idx] ? 'text' : 'password'}
                              value={entry.secret}
                              readOnly
                              className="bg-slate-700 text-white px-4 py-2 rounded flex-1 font-mono text-sm"
                            />
                            <button
                              onClick={() => setShowSecrets({ ...showSecrets, [idx]: !showSecrets[idx] })}
                              className="bg-slate-600 hover:bg-slate-500 text-white px-3 py-2 rounded"
                            >
                              {showSecrets[idx] ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                            </button>
                          </div>
                        </div>

                        <div>
                          <label className="text-sm text-purple-300 block mb-1">
                            2FA Code (expires in {timeLeft}s)
                          </label>
                          <div className="flex gap-2">
                            <input
                              type="text"
                              value={totpCodes[idx] || '------'}
                              readOnly
                              className="bg-gradient-to-r from-green-900 to-green-800 text-green-100 px-4 py-2 rounded flex-1 font-mono text-2xl text-center tracking-widest"
                            />
                            <button
                              onClick={() => handleCopy(totpCodes[idx], '2FA Code')}
                              className="bg-green-600 hover:bg-green-700 text-white px-3 py-2 rounded"
                            >
                              <Copy className="w-4 h-4" />
                            </button>
                          </div>
                        </div>
                      </>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Export/Import */}
        <div className="mt-8 text-center">
          <div className="flex gap-4 justify-center">
            <button
              onClick={handleExport}
              className="bg-purple-600 hover:bg-purple-700 text-white px-8 py-3 rounded-lg flex items-center gap-2 text-lg"
            >
              <Download className="w-5 h-5" />
              Export Vault
            </button>
            <button
              onClick={handleImport}
              className="bg-blue-600 hover:bg-blue-700 text-white px-8 py-3 rounded-lg flex items-center gap-2 text-lg"
            >
              <Upload className="w-5 h-5" />
              Import Vault
            </button>
          </div>
          <p className="text-purple-300 text-sm mt-2">
            {entries.length} password{entries.length !== 1 ? 's' : ''} • {apiKeys.length} API key
            {apiKeys.length !== 1 ? 's' : ''} • AES-256-GCM • PBKDF2 100k iterations
          </p>
        </div>

        {entries.length === 0 && apiKeys.length === 0 && (
          <div className="text-center text-purple-300 py-8">
            <Shield className="w-16 h-16 mx-auto mb-4 opacity-50" />
            <p className="text-xl">Your vault is empty. Add passwords, 2FA, or API keys above.</p>
          </div>
        )}
      </div>

      <PasswordModal {...passwordModal} onClose={() => setPasswordModal({ ...passwordModal, isOpen: false })} />
      <ToastContainer toasts={toasts} onRemove={removeToast} />
    </div>
  );
}
