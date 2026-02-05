// WebSocket Message Types
export enum MessageType {
  AudioIn = 0,
  Word = 2,
  EndWord = 3,
}

export interface WordMessage {
  type: MessageType.Word;
  word: string;
  timestamp: number;
  confidence?: number;
}

export interface EndWordMessage {
  type: MessageType.EndWord;
  timestamp: number;
}

export interface AudioMessage {
  type: MessageType.AudioIn;
  data: Uint8Array;
}

export type WebSocketMessage = WordMessage | EndWordMessage | AudioMessage;

// Transcript Types
export interface Sentence {
  text: string;
  timestamp: number;
  sent: boolean;
}

// Execution Types (must match Python ExecutionState enum)
export enum ExecutionState {
  PENDING = 'pending',
  RUNNING = 'running',
  WAITING_FOR_INPUT = 'waiting_for_input',
  COMPLETED = 'completed',
  FAILED = 'failed',
}

export interface ExecutionContext {
  session_id: string;
  state: ExecutionState;
  transcript: string[];
  commands: string[];
  results: Array<{ output: string; error?: string }>;
  current_question: string | null;
  question_context: string | null;
  answers: Array<{ question: string; answer: string }>;
  topics: string[];
  error_message: string | null;
  created_at: string; // ISO datetime
  updated_at: string; // ISO datetime
}

// API Response Types
export interface BackgroundExecuteResponse {
  session_id: string;
  state: ExecutionState;
}

export interface ResumeResponse {
  state: ExecutionState;
}
