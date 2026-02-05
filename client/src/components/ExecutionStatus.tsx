import type { ExecutionContext } from '../types';

interface ExecutionStatusProps {
  context: ExecutionContext | null;
  isLoading: boolean;
  error: string | null;
}

export function ExecutionStatus({ context, isLoading, error }: ExecutionStatusProps) {
  if (error) {
    return (
      <div className="w-full max-w-4xl mx-auto bg-red-50 border border-red-200 rounded-lg p-4">
        <p className="text-red-800 font-semibold">Error</p>
        <p className="text-red-600 text-sm">{error}</p>
      </div>
    );
  }

  if (!context && !isLoading) {
    return null;
  }

  const getStatusColor = (state: string) => {
    switch (state) {
      case 'pending':
        return 'bg-gray-100 text-gray-800 border-gray-200';
      case 'running':
        return 'bg-blue-50 text-blue-800 border-blue-200';
      case 'waiting_for_input':
        return 'bg-yellow-50 text-yellow-800 border-yellow-200';
      case 'completed':
        return 'bg-green-50 text-green-800 border-green-200';
      case 'failed':
        return 'bg-red-50 text-red-800 border-red-200';
      default:
        return 'bg-gray-100 text-gray-800 border-gray-200';
    }
  };

  return (
    <div className="w-full max-w-4xl mx-auto space-y-4">
      <div className={`border rounded-lg p-4 ${context ? getStatusColor(context.state) : 'bg-gray-50'}`}>
        <div className="flex items-center justify-between">
          <div>
            <p className="font-semibold">Execution Status</p>
            <p className="text-sm">{context?.state.replace('_', ' ').toUpperCase() || 'Loading...'}</p>
          </div>
          {isLoading && (
            <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-current"></div>
          )}
        </div>

        {context?.error_message && (
          <div className="mt-2 text-sm text-red-600">
            <p className="font-semibold">Error:</p>
            <p>{context.error_message}</p>
          </div>
        )}
      </div>

      {context && context.results.length > 0 && (
        <div className="bg-white border rounded-lg p-4 space-y-2">
          <p className="font-semibold">Results:</p>
          <div className="space-y-2 max-h-64 overflow-y-auto">
            {context.results.map((result, index) => (
              <div key={index} className="bg-gray-50 p-3 rounded text-sm">
                <pre className="whitespace-pre-wrap">{result.output}</pre>
                {result.error && (
                  <p className="text-red-600 mt-2">Error: {result.error}</p>
                )}
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
