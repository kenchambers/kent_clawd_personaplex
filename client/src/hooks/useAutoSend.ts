import { useRef, useCallback } from 'react';

interface UseAutoSendOptions {
  getUnsentText: () => string;
  markSent: () => void;
  onSend: (text: string) => Promise<void>;
  silenceThreshold?: number;  // Default 1500ms
  minWords?: number;          // Default 3
}

export function useAutoSend({
  getUnsentText,
  markSent,
  onSend,
  silenceThreshold = 1500,
  minWords = 3,
}: UseAutoSendOptions) {
  const wordCountRef = useRef(0);
  const timeoutRef = useRef<NodeJS.Timeout>();
  const isSendingRef = useRef(false); // Lock to prevent race condition

  const onWord = useCallback(() => {
    if (isSendingRef.current) return; // Ignore words during send

    wordCountRef.current++;

    // Clear existing timeout, set new one
    clearTimeout(timeoutRef.current);
    timeoutRef.current = setTimeout(async () => {
      if (isSendingRef.current) return; // Double-check lock

      const text = getUnsentText();

      // Validate: minimum words and non-empty
      if (wordCountRef.current >= minWords && text.trim().length > 0) {
        isSendingRef.current = true; // Acquire lock

        try {
          await onSend(text);
          markSent();
        } catch (err) {
          console.error('Failed to send transcript', err);
        } finally {
          wordCountRef.current = 0;
          isSendingRef.current = false; // Release lock
        }
      }
    }, silenceThreshold);
  }, [getUnsentText, markSent, onSend, silenceThreshold, minWords]);

  const reset = useCallback(() => {
    clearTimeout(timeoutRef.current);
    wordCountRef.current = 0;
    isSendingRef.current = false;
  }, []);

  return { onWord, reset };
}
