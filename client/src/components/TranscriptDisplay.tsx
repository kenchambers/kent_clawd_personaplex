import type { Sentence } from '../types';

interface TranscriptDisplayProps {
  sentences: Sentence[];
  currentWords: string[];
}

export function TranscriptDisplay({ sentences, currentWords }: TranscriptDisplayProps) {
  return (
    <div className="w-full max-w-4xl mx-auto bg-white shadow-lg rounded-lg p-6 space-y-2">
      <h2 className="text-xl font-bold mb-4">Live Transcript</h2>

      <div className="space-y-2 max-h-96 overflow-y-auto">
        {sentences.map((sentence, index) => (
          <div key={index} className="flex items-start gap-2">
            <p className="flex-1 text-gray-800">{sentence.text}</p>
            {sentence.sent && (
              <span className="px-2 py-1 bg-green-100 text-green-800 text-xs rounded">
                Sent
              </span>
            )}
          </div>
        ))}

        {currentWords.length > 0 && (
          <p className="text-gray-600 italic">{currentWords.join(' ')}</p>
        )}
      </div>

      {sentences.length === 0 && currentWords.length === 0 && (
        <p className="text-gray-400 text-center py-8">
          Start recording to see your transcript here...
        </p>
      )}
    </div>
  );
}
