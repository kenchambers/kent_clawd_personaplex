import OpusRecorder from 'opus-recorder';
import { useRef, useState, useCallback, useEffect } from 'react';
import { encodeHandshake, encodeAudio, decodeMessage } from '../protocol';

interface UseMoshiConnectionOptions {
  onText: (text: string) => void;
  onAudio?: (data: Uint8Array) => void;
  onError?: (error: string) => void;
}

export function useMoshiConnection({ onText, onAudio, onError }: UseMoshiConnectionOptions) {
  const wsRef = useRef<WebSocket | null>(null);
  const recorderRef = useRef<OpusRecorder | null>(null);
  const reconnectAttemptsRef = useRef(0);
  const reconnectTimeoutRef = useRef<NodeJS.Timeout>();
  const handshakeSentRef = useRef(false);

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
        console.log('WebSocket connected, sending handshake...');

        // Send required Moshi protocol handshake
        const handshake = encodeHandshake('0', '0');
        ws.send(handshake);
        handshakeSentRef.current = true;
        console.log('Handshake sent');

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
          const msg = decodeMessage(event.data);

          switch (msg.kind) {
            case 'text':
              // Moshi sends transcribed text tokens
              onText(msg.data);
              break;

            case 'audio':
              // Moshi sends audio response data
              onAudio?.(msg.data);
              break;

            case 'error':
              console.error('Moshi error:', msg.data);
              onError?.(msg.data);
              setError(msg.data);
              break;

            case 'handshake':
              console.log('Server handshake received:', msg);
              break;

            case 'control':
              console.log('Control message:', msg.action);
              break;

            case 'metadata':
              console.log('Metadata:', msg.data);
              break;

            case 'ping':
              // Respond to keep-alive pings if needed
              break;

            default:
              console.log('Unknown message:', msg);
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
  }, [getWebSocketUrl, onText, onAudio, onError]);

  const disconnect = useCallback(() => {
    if (reconnectTimeoutRef.current) {
      clearTimeout(reconnectTimeoutRef.current);
    }

    if (wsRef.current) {
      wsRef.current.close();
      wsRef.current = null;
    }

    handshakeSentRef.current = false;
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
          // Use Moshi binary protocol for audio
          const message = encodeAudio(audioData);
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
