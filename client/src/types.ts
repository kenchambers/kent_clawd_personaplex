// WebSocket Message Types are now in ./protocol/types.ts

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
