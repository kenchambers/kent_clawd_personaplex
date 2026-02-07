// Moshi Protocol Decoder
// Decodes binary messages from the Moshi WebSocket server

import {
  MessageTypeByte,
  CONTROL_ACTIONS_REVERSE,
  type MoshiMessage,
} from './types';

const textDecoder = new TextDecoder();

/**
 * Decode a binary message from the Moshi WebSocket protocol
 */
export function decodeMessage(data: ArrayBuffer): MoshiMessage {
  const bytes = new Uint8Array(data);

  if (bytes.length === 0) {
    throw new Error('Empty message received');
  }

  const typeByte = bytes[0];
  const payload = bytes.slice(1);

  switch (typeByte) {
    case MessageTypeByte.HANDSHAKE: {
      // Handshake: [type, version, model]
      const versionByte = payload[0] ?? 0;
      const modelByte = payload[1] ?? 0;
      return {
        kind: 'handshake',
        version: String(versionByte),
        model: String(modelByte),
      };
    }

    case MessageTypeByte.AUDIO: {
      // Audio: [type, ...audio_data]
      return {
        kind: 'audio',
        data: payload,
      };
    }

    case MessageTypeByte.TEXT: {
      // Text: [type, ...utf8_string]
      return {
        kind: 'text',
        data: textDecoder.decode(payload),
      };
    }

    case MessageTypeByte.CONTROL: {
      // Control: [type, action_byte]
      const actionByte = payload[0] ?? 0;
      const action = CONTROL_ACTIONS_REVERSE[actionByte];
      if (!action) {
        console.warn(`Unknown control action byte: ${actionByte}`);
        return { kind: 'control', action: 'start' }; // Default
      }
      return { kind: 'control', action };
    }

    case MessageTypeByte.METADATA: {
      // Metadata: [type, ...json_string]
      const jsonStr = textDecoder.decode(payload);
      try {
        return {
          kind: 'metadata',
          data: JSON.parse(jsonStr),
        };
      } catch {
        console.warn('Failed to parse metadata JSON:', jsonStr);
        return { kind: 'metadata', data: null };
      }
    }

    case MessageTypeByte.ERROR: {
      // Error: [type, ...utf8_string]
      return {
        kind: 'error',
        data: textDecoder.decode(payload),
      };
    }

    case MessageTypeByte.PING: {
      // Ping: [type]
      return { kind: 'ping' };
    }

    default:
      console.warn(`Unknown message type byte: 0x${typeByte.toString(16)}`);
      // Try to interpret as text for debugging
      return {
        kind: 'text',
        data: textDecoder.decode(bytes),
      };
  }
}
