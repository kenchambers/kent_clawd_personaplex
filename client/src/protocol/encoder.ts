// Moshi Protocol Encoder
// Encodes messages to binary format for WebSocket transmission

import {
  MessageTypeByte,
  VERSIONS_MAP,
  MODELS_MAP,
  CONTROL_ACTIONS,
  type MoshiMessage,
} from './types';

const textEncoder = new TextEncoder();

/**
 * Encode a message to binary format for the Moshi WebSocket protocol
 */
export function encodeMessage(message: MoshiMessage): Uint8Array {
  switch (message.kind) {
    case 'handshake': {
      const versionByte = VERSIONS_MAP[message.version] ?? 0;
      const modelByte = MODELS_MAP[message.model] ?? 0;
      return new Uint8Array([MessageTypeByte.HANDSHAKE, versionByte, modelByte]);
    }

    case 'audio': {
      const result = new Uint8Array(1 + message.data.length);
      result[0] = MessageTypeByte.AUDIO;
      result.set(message.data, 1);
      return result;
    }

    case 'text': {
      const textBytes = textEncoder.encode(message.data);
      const result = new Uint8Array(1 + textBytes.length);
      result[0] = MessageTypeByte.TEXT;
      result.set(textBytes, 1);
      return result;
    }

    case 'control': {
      const actionByte = CONTROL_ACTIONS[message.action];
      return new Uint8Array([MessageTypeByte.CONTROL, actionByte]);
    }

    case 'metadata': {
      const jsonBytes = textEncoder.encode(JSON.stringify(message.data));
      const result = new Uint8Array(1 + jsonBytes.length);
      result[0] = MessageTypeByte.METADATA;
      result.set(jsonBytes, 1);
      return result;
    }

    case 'error': {
      const errorBytes = textEncoder.encode(message.data);
      const result = new Uint8Array(1 + errorBytes.length);
      result[0] = MessageTypeByte.ERROR;
      result.set(errorBytes, 1);
      return result;
    }

    case 'ping': {
      return new Uint8Array([MessageTypeByte.PING]);
    }

    default:
      throw new Error(`Unknown message kind: ${(message as MoshiMessage).kind}`);
  }
}

// Helper functions for common operations
export function encodeHandshake(version = '0', model = '0'): Uint8Array {
  return encodeMessage({ kind: 'handshake', version, model });
}

export function encodeAudio(data: Uint8Array): Uint8Array {
  return encodeMessage({ kind: 'audio', data });
}

export function encodeControl(action: 'start' | 'endTurn' | 'pause' | 'restart'): Uint8Array {
  return encodeMessage({ kind: 'control', action });
}

export function encodePing(): Uint8Array {
  return encodeMessage({ kind: 'ping' });
}
