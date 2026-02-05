import { useState, useEffect } from 'react';
import { getExecutionContext } from '../api/orchestrator';
import type { ExecutionContext } from '../types';

const POLL_INTERVAL = 2000; // 2 seconds
const MAX_POLL_FAILURES = 3;

export function useExecution(sessionId: string | null) {
  const [context, setContext] = useState<ExecutionContext | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    if (!sessionId) {
      setContext(null);
      return;
    }

    let pollFailures = 0;
    let isMounted = true;

    const poll = async () => {
      if (!isMounted) return;

      try {
        const ctx = await getExecutionContext(sessionId);

        if (!isMounted) return;

        setContext(ctx);
        setError(null);
        pollFailures = 0; // Reset on success

        // Stop polling on terminal states
        if (ctx.state === 'completed' || ctx.state === 'failed') {
          clearInterval(interval);
          setIsLoading(false);
        }
      } catch (err) {
        pollFailures++;

        if (pollFailures >= MAX_POLL_FAILURES) {
          clearInterval(interval);
          setError(
            'Lost connection to execution. Session may have expired or server is unavailable.'
          );
          setIsLoading(false);
        }

        console.error('Poll error', err);
      }
    };

    setIsLoading(true);
    poll(); // Initial fetch
    const interval = setInterval(poll, POLL_INTERVAL);

    return () => {
      isMounted = false;
      clearInterval(interval);
    };
  }, [sessionId]);

  return { context, error, isLoading };
}
