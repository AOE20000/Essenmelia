import React, { createContext, useContext, useState, useCallback, ReactNode } from 'react';
import BaseWindow, { WindowVariant } from '../components/ui/BaseWindow';

// --- Import Feature Modules ---
import { EditEventModule } from '../features/events/EditEventModule';
import { SettingsModule } from '../features/settings/SettingsModule';
import { DatabaseManagerModule } from '../features/settings/DatabaseManagerModule';
import { TagManagerModule } from '../features/tags/TagManagerModule';
import { SelectionTagManagerModule } from '../features/tags/SelectionTagManagerModule';
import { StepsEditorModule } from '../features/editor/StepsEditorModule';
import { WelcomeModule } from '../features/onboarding/WelcomeModule';
import { NotificationModule } from '../features/misc/NotificationModule';
import { ConfirmDialogModule } from '../features/misc/ConfirmDialogModule';
import { PromptModule } from '../features/misc/PromptModule';
import { PlusIcon } from '../components/ui/icons';
import { useDatabase } from './DatabaseContext';

// Define Registry
export type WindowRegistry = {
  'edit-event': { eventId?: string };
  'settings': Record<string, never>; // Empty object
  'db-manager': Record<string, never>;
  'manage-tags': Record<string, never>;
  'manage-selection-tags': { selectedEventIds: string[] };
  'steps-editor': { eventId: string };
  'welcome': Record<string, never>;
  'create-db': Record<string, never>;
  'notification': { title?: string, message: string, type?: 'success'|'error'|'info', onConfirm?: () => void };
  'confirm': { title?: string, message: string, confirmText?: string, isDestructive?: boolean, onConfirm: () => void };
  'prompt': { title?: string, message?: string, defaultValue?: string, placeholder?: string, confirmText?: string, onConfirm: (val: string) => void };
  'import-confirm': { file: File, onConfirm?: () => void };
};

type WindowKey = keyof WindowRegistry;

type WindowItem = {
  id: string;
  key: WindowKey;
  props: any;
  variant: WindowVariant;
  title?: string;
  // State lifted from module to window container
  headerContent?: ReactNode;
  overrideCloseAction?: (() => void) | null;
};

interface WindowContextType {
  open: <K extends WindowKey>(
    key: K, 
    props: WindowRegistry[K], 
    options?: { title?: string, variant?: WindowVariant }
  ) => void;
  close: (id?: string) => void;
  closeAll: () => void;
  // Allow modules to update their window container
  setHeader: (id: string, content: ReactNode) => void;
  setOverrideCloseAction: (id: string, action: (() => void) | null) => void;
}

const WindowContext = createContext<WindowContextType | null>(null);

export const WindowProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  const [stack, setStack] = useState<WindowItem[]>([]);
  const { createDb } = useDatabase(); // Used in inline component for create-db

  const open = useCallback((key: any, props: any, options: any) => {
    setStack(prev => {
        // Prevent duplicates
        const isDuplicate = prev.some(w => {
            if (w.key !== key) return false;
            
            // For simple singletons
            if (['settings', 'db-manager', 'welcome', 'manage-tags'].includes(key)) return true;
            
            // For parameter-based windows, check identifying props
            if (key === 'edit-event' || key === 'steps-editor') {
                return w.props.eventId === props.eventId;
            }
            if (key === 'manage-selection-tags') {
                return JSON.stringify(w.props.selectedEventIds) === JSON.stringify(props.selectedEventIds);
            }
            
            return false;
        });

        if (isDuplicate) return prev;

        const id = Math.random().toString(36).substr(2, 9);
        // Determine default variant
        let defaultVariant: WindowVariant = 'dialog';
        if (['edit-event', 'settings', 'db-manager', 'manage-tags', 'manage-selection-tags', 'steps-editor', 'create-db', 'welcome'].includes(key)) {
            defaultVariant = 'sheet';
        }

        return [...prev, { 
            id, 
            key, 
            props, 
            variant: options?.variant || defaultVariant, 
            title: options?.title 
        }];
    });
  }, []);

  const close = useCallback((id?: string) => {
    setStack(prev => id ? prev.filter(w => w.id !== id) : prev.slice(0, -1));
  }, []);

  const closeAll = useCallback(() => setStack([]), []);

  const setHeader = useCallback((id: string, content: ReactNode) => {
      setStack(prev => prev.map(w => w.id === id ? { ...w, headerContent: content } : w));
  }, []);

  const setOverrideCloseAction = useCallback((id: string, action: (() => void) | null) => {
      setStack(prev => prev.map(w => w.id === id ? { ...w, overrideCloseAction: action } : w));
  }, []);

  // --- Module Mapping ---
  const renderModule = (key: WindowKey, props: any, windowId: string) => {
      const commonProps = { closeWindow: () => close(windowId) };
      
      switch (key) {
          case 'edit-event': return <EditEventModule {...props} {...commonProps} />;
          case 'settings': return <SettingsModule {...commonProps} />;
          case 'db-manager': return <DatabaseManagerModule {...commonProps} />;
          case 'manage-tags': return <TagManagerModule {...commonProps} setHeader={(n) => setHeader(windowId, n)} setOverrideCloseAction={(a) => setOverrideCloseAction(windowId, a)} />;
          case 'manage-selection-tags': return <SelectionTagManagerModule {...props} {...commonProps} />;
          case 'steps-editor': return <StepsEditorModule {...props} {...commonProps} setHeader={(n) => setHeader(windowId, n)} setOverrideCloseAction={(a) => setOverrideCloseAction(windowId, a)} />;
          case 'welcome': return <WelcomeModule {...commonProps} />;
          case 'notification': return <NotificationModule {...props} {...commonProps} />;
          case 'confirm': return <ConfirmDialogModule {...props} {...commonProps} />;
          case 'prompt': return <PromptModule {...props} {...commonProps} />;
          case 'create-db': 
            // Inline small form
            return (
                <CreateDbModule createDb={createDb} closeWindow={() => close(windowId)} />
            );
          case 'import-confirm':
             return (
                 <div className="space-y-4">
                     <p>您确定要导入此文件吗？这将添加数据到当前数据库。</p>
                     <div className="flex justify-end gap-2">
                         <button onClick={() => close(windowId)} className="px-4 py-2 rounded-lg text-slate-600 hover:bg-slate-100 dark:text-slate-300 dark:hover:bg-slate-700">取消</button>
                         <button onClick={() => { if(props.onConfirm) props.onConfirm(); close(windowId); }} className="px-4 py-2 rounded-lg bg-slate-900 text-white dark:bg-slate-200 dark:text-slate-900 font-medium">确认导入</button>
                     </div>
                 </div>
             )
          default: return null;
      }
  };

  return (
    <WindowContext.Provider value={{ open, close, closeAll, setHeader, setOverrideCloseAction }}>
      {children}
      {stack.map((window, index) => {
        // If override action exists, intercept the close request
        const handleCloseRequest = () => {
            if (window.overrideCloseAction) {
                window.overrideCloseAction();
            } else {
                close(window.id);
            }
        };

        return (
          <BaseWindow
            key={window.id}
            isOpen={true} 
            onClose={handleCloseRequest}
            title={window.title}
            headerContent={window.headerContent}
            variant={window.variant}
            zIndex={100 + index}
            // For sheets like 'welcome' we might want custom width, handle via a map or prop if needed.
            width={window.key === 'welcome' ? 'md' : (window.key === 'steps-editor' ? 'full' : 'md')}
            contentClass={window.key === 'steps-editor' ? "h-full max-h-[95vh] lg:h-full lg:max-h-[90vh]" : undefined}
          >
            {renderModule(window.key, window.props, window.id)}
          </BaseWindow>
        );
      })}
    </WindowContext.Provider>
  );
};

export const useWindow = () => {
  const context = useContext(WindowContext);
  if (!context) throw new Error("useWindow must be used within WindowProvider");
  return context;
};

// Inline helper for create DB to keep Context clean
const CreateDbModule: React.FC<{ createDb: (name: string) => Promise<void>, closeWindow: () => void }> = ({ createDb, closeWindow }) => {
    const [name, setName] = useState('');
    const handleCreate = () => {
        if(name.trim()) {
            createDb(name.trim());
            closeWindow();
        }
    };
    return (
        <div className="space-y-4">
            <p className="text-sm text-slate-500 dark:text-slate-400">为一组新项目创建一个单独的数据库。</p>
            <div>
                <label className="block text-sm font-medium mb-1">数据库名称</label>
                <input autoFocus type="text" value={name} onChange={e => setName(e.target.value)} onKeyDown={e => e.key === 'Enter' && handleCreate()} className="w-full px-3 py-2 border border-slate-300 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-700" />
            </div>
            <div className="flex justify-end gap-3">
                <button onClick={closeWindow} className="px-4 py-2 rounded bg-slate-200 dark:bg-slate-600">取消</button>
                <button onClick={handleCreate} className="px-4 py-2 rounded bg-slate-900 text-white dark:bg-slate-200 dark:text-slate-900 flex items-center gap-2">
                    <PlusIcon className="w-4 h-4" /> 创建
                </button>
            </div>
        </div>
    );
}