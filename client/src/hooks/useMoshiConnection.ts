import { encode, decode } from '@msgpack/msgpack';
import OpusRecorder from 'opus-recorder';
import { useRef, useState, useCallback, useEffect } from 'react';
import type { WebSocketMessage } from '../types';

interface UseMoshiConnectionOptions {
  onWord: (word: string, timestamp: number) => void;
  onEndWord: (timestamp: number) => void;
}

export function useMoshiConnection({ onWord, onEndWord }: UseMoshiConnectionOptions) {
  const wsRef = useRef<WebSocket | null>(null);
  const recorderRef = useRef<OpusRecorder | null>(null);
  const reconnectAttemptsRef = useRef(0);
  const reconnectTimeoutRef = useRef<NodeJS.Timeout>();

  const [isConnected, setIsConnected] = useState(false);
  const [isRecording, setIsRecording] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const MAX_RECONNECT_ATTEMPTS = 5;
  const BASE_RECONNECT_DELAY = 1000;
  const MAX_RECONNECT_DELAY = 30000;

  // Dynamic WebSocket URL (fixes hardcoding issue)
  const getWebSocketUrl = useCallback(() => {
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const host = window.location.host;
    return `${protocol}//${host}/api/chat`;
  }, []);

  const connect = useCallback(() => {
    try {
      const url = getWebSocketUrl();
      const ws = new WebSocket(url);
      ws.binaryType = 'arraybuffer';

      ws.onopen = () => {
        console.log('WebSocket connected');
        setIsConnected(true);
        setError(null);
        reconnectAttemptsRef.current = 0; // Reset on success
      };

      ws.onclose = (event) => {
        console.log('WebSocket closed', event.code, event.reason);
        setIsConnected(false);

        // Attempt reconnection if not clean close
        if (!event.wasClean && reconnectAttemptsRef.current < MAX_RECONNECT_ATTEMPTS) {
          const delay = Math.min(
            BASE_RECONNECT_DELAY * Math.pow(2, reconnectAttemptsRef.current),
            MAX_RECONNECT_DELAY
          );

          console.log(`Reconnecting in ${delay}ms (attempt ${reconnectAttemptsRef.current + 1}/${MAX_RECONNECT_ATTEMPTS})`);

          reconnectTimeoutRef.current = setTimeout(() => {
            reconnectAttemptsRef.current++;
            connect();
          }, delay);
        } else if (reconnectAttemptsRef.current >= MAX_RECONNECT_ATTEMPTS) {
          setError('Failed to connect after multiple attempts. Please refresh the page.');
        }
      };

      ws.onerror = (error) => {
        console.error('WebSocket error', error);
        setError('WebSocket connection error');
      };

      ws.onmessage = (event) => {
        try {
          const msg = decode(new Uint8Array(event.data)) as WebSocketMessage;

          if (msg.type === 2) { // MessageType.Word
            onWord(msg.word, msg.timestamp);
          } else if (msg.type === 3) { // MessageType.EndWord
            onEndWord(msg.timestamp);
          }
        } catch (err) {
          console.error('Failed to decode message', err);
        }
      };

      wsRef.current = ws;
    } catch (err) {
      console.error('Failed to create WebSocket', err);
      setError('Failed to create WebSocket connection');
    }
  }, [getWebSocketUrl, onWord, onEndWord]);

  const disconnect = useCallback(() => {
    if (reconnectTimeoutRef.current) {
      clearTimeout(reconnectTimeoutRef.current);
    }

    if (wsRef.current) {
      wsRef.current.close();
      wsRef.current = null;
    }

    setIsConnected(false);
  }, []);

  const startRecording = useCallback(async () => {
    if (!isConnected) {
      setError('WebSocket not connected');
      return;
    }

    try {
      const recorder = new OpusRecorder({
        encoderPath: '/opus-encoder.js',
        encoderSampleRate: 24000,
        encoderFrameSize: 960,  // 40ms at 24kHz
        streamPages: true,      // Low latency streaming
      });

      recorder.ondataavailable = (arrayBuffer: ArrayBuffer) => {
        if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
          const audioData = new Uint8Array(arrayBuffer);
          const message = encode({ type: 0, data: audioData }); // MessageType.AudioIn
          wsRef.current.send(message);
        }
      };

      await recorder.start();
      recorderRef.current = recorder;
      setIsRecording(true);
      setError(null);
    } catch (err) {
      console.error('Failed to start recording', err);
      setError('Failed to access microphone. Please grant permission.');
    }
  }, [isConnected]);

  const stopRecording = useCallback(async () => {
    if (recorderRef.current) {
      await recorderRef.current.stop();
      recorderRef.current = null;
    }
    setIsRecording(false);
  }, []);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      disconnect();
      if (recorderRef.current) {
        recorderRef.current.stop();
      }
    };
  }, [disconnect]);

  return {
    isConnected,
    isRecording,
    error,
    connect,
    disconnect,
    startRecording,
    stopRecording,
  };
}
