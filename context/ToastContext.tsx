import React, { createContext, useContext, useState, useCallback, useEffect } from 'react';
import Snackbar, { SnackbarType } from '../components/ui/Snackbar';
import { ArchiveBoxIcon } from '../components/ui/icons';

interface Toast {
  id: number;
  message: string;
  type: SnackbarType;
  icon?: React.ReactNode;
  duration?: number;
}

interface ToastContextType {
  showToast: (message: string, type?: SnackbarType, icon?: React.ReactNode, duration?: number) => void;
  // Special specific toast for DB status which might persist longer or change states
  setDbStatus: (status: { message: string; type: SnackbarType } | null) => void;
}

const ToastContext = createContext<ToastContextType | null>(null);

export const ToastProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [toast, setToast] = useState<Toast | null>(null);
  const [dbStatus, setDbStatusInternal] = useState<Toast | null>(null);

  const showToast = useCallback((message: string, type: SnackbarType = 'info', icon?: React.ReactNode, duration = 3000) => {
    const id = Date.now();
    setToast({ id, message, type, icon, duration });
    
    setTimeout(() => {
      setToast(prev => (prev?.id === id ? null : prev));
    }, duration);
  }, []);

  const setDbStatus = useCallback((status: { message: string; type: SnackbarType } | null) => {
    if (!status) {
      setDbStatusInternal(null);
      return;
    }
    const id = Date.now();
    setDbStatusInternal({ id, message: status.message, type: status.type });
  }, []);

  // Auto-dismiss logic for dbStatus
  useEffect(() => {
    if (!dbStatus) return;
    
    // Loading states don't auto-dismiss. Success/Info/Error do.
    if (dbStatus.type !== 'loading') {
       const timer = setTimeout(() => {
           setDbStatusInternal(prev => prev?.id === dbStatus.id ? null : prev);
       }, 4000);
       return () => clearTimeout(timer);
    }
  }, [dbStatus]);

  return (
    <ToastContext.Provider value={{ showToast, setDbStatus }}>
      {children}
      
      {/* DB Status Toast (Higher priority/Bottom position) */}
      <Snackbar
        isOpen={!!dbStatus}
        message={dbStatus?.message || ''}
        type={dbStatus?.type}
        bottomClass="bottom-8"
      />
      
      {/* General Action Toast (Stacks above DB status if both exist) */}
      <Snackbar
        isOpen={!!toast}
        message={toast?.message || ''}
        type={toast?.type}
        icon={toast?.icon || (toast?.type === 'info' ? <ArchiveBoxIcon className="w-5 h-5"/> : undefined)}
        bottomClass={dbStatus ? 'bottom-24' : 'bottom-8'}
      />
    </ToastContext.Provider>
  );
};

export const useToast = () => {
  const context = useContext(ToastContext);
  if (!context) throw new Error("useToast must be used within ToastProvider");
  return context;
};