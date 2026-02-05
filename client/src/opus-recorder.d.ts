declare module 'opus-recorder' {
  interface OpusRecorderConfig {
    encoderPath: string;
    encoderSampleRate: number;
    encoderFrameSize: number;
    streamPages: boolean;
  }

  class OpusRecorder {
    constructor(config: OpusRecorderConfig);
    ondataavailable: ((arrayBuffer: ArrayBuffer) => void) | null;
    start(): Promise<void>;
    stop(): Promise<void>;
  }

  export default OpusRecorder;
}
