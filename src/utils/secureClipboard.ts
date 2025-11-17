/**
 * Securely copies text to clipboard with auto-clear and feedback
 */

let clearTimer: number | null = null;

export async function secureCopyToClipboard(
  text: string,
  options: {
    autoClearSeconds?: number;
    onCopied?: () => void;
    onCleared?: () => void;
    onError?: (error: Error) => void;
  } = {}
): Promise<boolean> {
  const {
    autoClearSeconds = 30,
    onCopied,
    onCleared,
    onError,
  } = options;

  try {
    // Clear any existing timer
    if (clearTimer) {
      clearTimeout(clearTimer);
      clearTimer = null;
    }

    // Copy to clipboard
    await navigator.clipboard.writeText(text);
    onCopied?.();

    // Auto-clear clipboard after timeout
    if (autoClearSeconds > 0) {
      clearTimer = setTimeout(async () => {
        try {
          // Check if our text is still in clipboard before clearing
          const currentClipboard = await navigator.clipboard.readText();
          if (currentClipboard === text) {
            await navigator.clipboard.writeText('');
            onCleared?.();
          }
        } catch (err) {
          // Ignore errors when clearing (might not have permission)
          console.warn('Could not auto-clear clipboard:', err);
        }
        clearTimer = null;
      }, autoClearSeconds * 1000);
    }

    return true;
  } catch (error) {
    const err = error instanceof Error ? error : new Error('Failed to copy to clipboard');
    onError?.(err);
    return false;
  }
}

/**
 * Manually clear the clipboard timer
 */
export function cancelClipboardClear() {
  if (clearTimer) {
    clearTimeout(clearTimer);
    clearTimer = null;
  }
}

/**
 * Immediately clear the clipboard
 */
export async function clearClipboard(): Promise<void> {
  try {
    await navigator.clipboard.writeText('');
    cancelClipboardClear();
  } catch (err) {
    console.warn('Could not clear clipboard:', err);
  }
}
