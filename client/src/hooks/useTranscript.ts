import { useState, useCallback } from 'react';
import type { Sentence } from '../types';

export function useTranscript() {
  const [sentences, setSentences] = useState<Sentence[]>([]);
  const [currentWords, setCurrentWords] = useState<string[]>([]);

  const addWord = useCallback((word: string) => {
    setCurrentWords(prev => [...prev, word]);
  }, []);

  const endSentence = useCallback(() => {
    setCurrentWords(prev => {
      if (prev.length === 0) return [];

      setSentences(s => [...s, {
        text: prev.join(' '),
        timestamp: Date.now(),
        sent: false,
      }]);

      return [];
    });
  }, []);

  const getUnsentText = useCallback(() => {
    return sentences
      .filter(s => !s.sent)
      .map(s => s.text)
      .join(' ');
  }, [sentences]);

  const markSent = useCallback(() => {
    setSentences(prev => prev.map(s => s.sent ? s : { ...s, sent: true }));
  }, []);

  const reset = useCallback(() => {
    setSentences([]);
    setCurrentWords([]);
  }, []);

  return {
    sentences,
    currentWords,
    addWord,
    endSentence,
    getUnsentText,
    markSent,
    reset,
  };
}
