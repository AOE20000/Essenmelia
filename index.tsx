import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import { ToastProvider } from './context/ToastContext';
import { DatabaseProvider } from './context/DatabaseContext';
import { EventsProvider } from './context/EventsContext';
import { WindowProvider } from './context/WindowContext';

const rootElement = document.getElementById('root');
if (!rootElement) {
  throw new Error("Could not find root element to mount to");
}

const root = ReactDOM.createRoot(rootElement);
root.render(
  <React.StrictMode>
    <ToastProvider>
      <DatabaseProvider>
        <EventsProvider>
          <WindowProvider>
            <App />
          </WindowProvider>
        </EventsProvider>
      </DatabaseProvider>
    </ToastProvider>
  </React.StrictMode>
);