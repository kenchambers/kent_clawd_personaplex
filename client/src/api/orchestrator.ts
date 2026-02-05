import type { ExecutionContext, BackgroundExecuteResponse, ResumeResponse } from '../types';

const API_TIMEOUT = 10000; // 10 seconds

class ApiError extends Error {
  constructor(public status: number, message: string) {
    super(message);
    this.name = 'ApiError';
  }
}

async function fetchWithTimeout(
  url: string,
  options: RequestInit,
  timeout = API_TIMEOUT
): Promise<Response> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeout);

  try {
    const response = await fetch(url, {
      ...options,
      signal: controller.signal,
    });
    clearTimeout(timeoutId);
    return response;
  } catch (err) {
    clearTimeout(timeoutId);
    if (err instanceof Error && err.name === 'AbortError') {
      throw new ApiError(504, 'Request timed out');
    }
    throw err;
  }
}

export async function executeBackground(
  payload: { transcript: string }
): Promise<BackgroundExecuteResponse> {
  const response = await fetchWithTimeout('/api/execute/background', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const error = await response.json().catch(() => ({ detail: 'Unknown error' }));
    throw new ApiError(response.status, error.detail || 'Failed to start execution');
  }

  return response.json();
}

export async function getExecutionContext(sessionId: string): Promise<ExecutionContext> {
  const response = await fetchWithTimeout(`/api/context/${sessionId}`, {
    method: 'GET',
  });

  if (!response.ok) {
    throw new ApiError(response.status, 'Failed to fetch execution context');
  }

  return response.json();
}

export async function resumeExecution(
  sessionId: string,
  answer: string
): Promise<ResumeResponse> {
  const response = await fetchWithTimeout(`/api/resume/${sessionId}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ answer }),
  });

  if (!response.ok) {
    const error = await response.json().catch(() => ({ detail: 'Unknown error' }));
    throw new ApiError(response.status, error.detail || 'Failed to resume execution');
  }

  return response.json();
}
