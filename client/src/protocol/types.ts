// Moshi Protocol Types
// Based on kyutai-labs/moshi client protocol

// Message type bytes
export const MessageTypeByte = {
  HANDSHAKE: 0x00,
  AUDIO: 0x01,
  TEXT: 0x02,
  CONTROL: 0x03,
  METADATA: 0x04,
  ERROR: 0x05,
  PING: 0x06,
} as const;

// Version map (currently only v0)
export const VERSIONS_MAP: Record<string, number> = {
  '0': 0b00000000,
};

// Model map (currently only model 0)
export const MODELS_MAP: Record<string, number> = {
  '0': 0b00000000,
};

// Control action codes
export const CONTROL_ACTIONS = {
  start: 0b00000000,
  endTurn: 0b00000001,
  pause: 0b00000010,
  restart: 0b00000011,
} as const;

export type ControlAction = keyof typeof CONTROL_ACTIONS;

// Reverse lookup for decoding
export const CONTROL_ACTIONS_REVERSE: Record<number, ControlAction> = {
  0b00000000: 'start',
  0b00000001: 'endTurn',
  0b00000010: 'pause',
  0b00000011: 'restart',
};

// Message types for TypeScript
export type HandshakeMessage = {
  kind: 'handshake';
  version: string;
  model: string;
};

export type AudioMessage = {
  kind: 'audio';
  data: Uint8Array;
};

export type TextMessage = {
  kind: 'text';
  data: string;
};

export type ControlMessage = {
  kind: 'control';
  action: ControlAction;
};

export type MetadataMessage = {
  kind: 'metadata';
  data: unknown;
};

export type ErrorMessage = {
  kind: 'error';
  data: string;
};

export type PingMessage = {
  kind: 'ping';
};

export type MoshiMessage =
  | HandshakeMessage
  | AudioMessage
  | TextMessage
  | ControlMessage
  | MetadataMessage
  | ErrorMessage
  | PingMessage;
