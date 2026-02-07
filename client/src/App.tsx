import { useState, useCallback } from 'react';
import { useMoshiConnection } from './hooks/useMoshiConnection';
import { useTranscript } from './hooks/useTranscript';
import { useAutoSend } from './hooks/useAutoSend';
import { useExecution } from './hooks/useExecution';
import { executeBackground, resumeExecution } from './api/orchestrator';
import { RecordButton } from './components/RecordButton';
import { TranscriptDisplay } from './components/TranscriptDisplay';
import { ExecutionStatus } from './components/ExecutionStatus';
import { QuestionPrompt } from './components/QuestionPrompt';

function App() {
  const [sessionId, setSessionId] = useState<string | null>(null);

  // Transcript management
  const {
    sentences,
    currentWords,
    addWord,
    endSentence,
    getUnsentText,
    markSent,
  } = useTranscript();

  // Auto-send handler
  const handleSend = useCallback(async (text: string) => {
    try {
      const response = await executeBackground({ transcript: text });
      setSessionId(response.session_id);
    } catch (err) {
      console.error('Failed to execute background', err);
    }
  }, []);

  // Auto-send logic with silence detection
  const { onWord: onAutoSendWord } = useAutoSend({
    getUnsentText,
    markSent,
    onSend: handleSend,
  });

  // Text event handler - receives transcribed text tokens from Moshi
  const handleText = useCallback((text: string) => {
    // Moshi sends text tokens (words or punctuation)
    // Add each token and trigger auto-send detection
    if (text.trim()) {
      addWord(text);
      onAutoSendWord(); // Trigger auto-send silence detection

      // End sentence on terminal punctuation
      if (text.match(/[.!?]$/)) {
        endSentence();
      }
    }
  }, [addWord, onAutoSendWord, endSentence]);

  // Moshi WebSocket + Audio connection
  const {
    isConnected,
    isRecording,
    error: connectionError,
    connect,
    startRecording,
    stopRecording,
  } = useMoshiConnection({
    onText: handleText,
  });

  // Execution status monitoring
  const { context, error: executionError, isLoading } = useExecution(sessionId);

  // Handle question answer submission
  const handleAnswerSubmit = useCallback(async (answer: string) => {
    if (!sessionId) return;
    await resumeExecution(sessionId, answer);
  }, [sessionId]);

  return (
    <div className="min-h-screen bg-gray-50 py-8 px-4">
      <div className="max-w-6xl mx-auto space-y-6">
        {/* Header */}
        <div className="text-center">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">
            PersonaPlex Voice Assistant
          </h1>
          <p className="text-gray-600">
            Speak naturally and let Moltbot execute your commands
          </p>
        </div>

        {/* Connection/Recording Controls */}
        <div className="flex justify-center">
          <RecordButton
            isConnected={isConnected}
            isRecording={isRecording}
            onConnect={connect}
            onStartRecording={startRecording}
            onStopRecording={stopRecording}
          />
        </div>

        {/* Connection Error */}
        {connectionError && (
          <div className="w-full max-w-4xl mx-auto bg-red-50 border border-red-200 rounded-lg p-4">
            <p className="text-red-800 font-semibold">Connection Error</p>
            <p className="text-red-600 text-sm">{connectionError}</p>
          </div>
        )}

        {/* Transcript Display */}
        {(sentences.length > 0 || currentWords.length > 0) && (
          <TranscriptDisplay sentences={sentences} currentWords={currentWords} />
        )}

        {/* Execution Status */}
        {(context || isLoading || executionError) && (
          <ExecutionStatus
            context={context}
            isLoading={isLoading}
            error={executionError}
          />
        )}

        {/* Question Prompt */}
        {context?.state === 'waiting_for_input' && context.current_question && (
          <QuestionPrompt
            question={context.current_question}
            questionContext={context.question_context}
            onSubmit={handleAnswerSubmit}
          />
        )}
      </div>
    </div>
  );
}

export default App;
