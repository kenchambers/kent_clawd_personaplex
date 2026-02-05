interface RecordButtonProps {
  isConnected: boolean;
  isRecording: boolean;
  onConnect: () => void;
  onStartRecording: () => void;
  onStopRecording: () => void;
}

export function RecordButton({
  isConnected,
  isRecording,
  onConnect,
  onStartRecording,
  onStopRecording,
}: RecordButtonProps) {
  if (!isConnected) {
    return (
      <button
        onClick={onConnect}
        className="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition"
      >
        Connect to Moshi
      </button>
    );
  }

  return (
    <button
      onClick={isRecording ? onStopRecording : onStartRecording}
      className={`px-6 py-3 rounded-lg transition ${
        isRecording
          ? 'bg-red-600 hover:bg-red-700 text-white'
          : 'bg-green-600 hover:bg-green-700 text-white'
      }`}
    >
      {isRecording ? 'Stop Recording' : 'Start Recording'}
    </button>
  );
}
