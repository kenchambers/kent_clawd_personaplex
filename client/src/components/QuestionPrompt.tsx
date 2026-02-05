import React, { useState } from 'react';

interface QuestionPromptProps {
  question: string;
  questionContext: string | null;
  onSubmit: (answer: string) => void;
}

export function QuestionPrompt({ question, questionContext, onSubmit }: QuestionPromptProps) {
  const [answer, setAnswer] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!answer.trim() || isSubmitting) return;

    setIsSubmitting(true);
    try {
      await onSubmit(answer.trim());
      setAnswer('');
    } catch (err) {
      console.error('Failed to submit answer', err);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="w-full max-w-4xl mx-auto bg-yellow-50 border border-yellow-200 rounded-lg p-6">
      <div className="mb-4">
        <p className="text-yellow-800 font-semibold mb-2">Moltbot has a question:</p>
        <p className="text-gray-800 text-lg">{question}</p>
        {questionContext && (
          <p className="text-gray-600 text-sm mt-2">Context: {questionContext}</p>
        )}
      </div>

      <form onSubmit={handleSubmit} className="space-y-3">
        <input
          type="text"
          value={answer}
          onChange={(e) => setAnswer(e.target.value)}
          placeholder="Type your answer..."
          className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-yellow-500 focus:border-transparent"
          disabled={isSubmitting}
        />
        <button
          type="submit"
          disabled={!answer.trim() || isSubmitting}
          className="px-6 py-2 bg-yellow-600 text-white rounded-lg hover:bg-yellow-700 transition disabled:bg-gray-400 disabled:cursor-not-allowed"
        >
          {isSubmitting ? 'Submitting...' : 'Submit Answer'}
        </button>
      </form>
    </div>
  );
}
