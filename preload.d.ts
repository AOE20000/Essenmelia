// preload.d.ts
export {};

declare global {
  interface Window {
    electronAPI: {
      ping: () => string;
      send: (channel: 'toMain', data: any) => void;
      on: (channel: 'fromMain', callback: (...args: any[]) => void) => void;
      removeListener: (channel: 'fromMain', callback: (...args: any[]) => void) => void;
    };
  }
}
