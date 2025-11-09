import React, { useEffect, useRef, useState } from 'react';

export interface ContextMenuAction {
  label: string;
  icon: React.ReactNode;
  onClick: () => void;
  isDestructive?: boolean;
}

interface ContextMenuProps {
  x: number;
  y: number;
  actions: ContextMenuAction[];
  onClose: () => void;
}

const ContextMenu: React.FC<ContextMenuProps> = ({ x, y, actions, onClose }) => {
  const menuRef = useRef<HTMLDivElement>(null);
  const [isClosing, setIsClosing] = useState(false);

  const handleClose = () => {
    setIsClosing(true);
    setTimeout(onClose, 300); // Match animation duration
  };

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(event.target as Node)) {
        handleClose();
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [onClose]);

  const menuStyle: React.CSSProperties = {
    top: `${y}px`,
    left: `${x}px`,
  };
  
  const handleActionClick = (action: ContextMenuAction) => {
    action.onClick();
    handleClose();
  };


  return (
    <>
      {/* Desktop pop-over */}
      <div className="hidden sm:block">
        <div className="fixed inset-0 z-50" onClick={handleClose} onContextMenu={(e) => { e.preventDefault(); handleClose(); }}></div>
        <div
          ref={menuRef}
          style={menuStyle}
          className={`fixed z-50 min-w-[180px] bg-slate-50 dark:bg-slate-700 rounded-xl shadow-lg p-2 text-sm ${isClosing ? 'animate-dialog-exit' : 'animate-dialog-enter'}`}
        >
          <ul>
            {actions.map((action, index) => (
              <li key={index}>
                <button
                  onClick={() => handleActionClick(action)}
                  className={`w-full flex items-center gap-3 px-3 py-2.5 text-left rounded-lg transition-colors ${
                    action.isDestructive
                      ? 'text-red-600 dark:text-red-400 hover:bg-red-100 dark:hover:bg-red-900/50'
                      : 'text-slate-700 dark:text-slate-200 hover:bg-slate-200 dark:hover:bg-slate-600'
                  }`}
                >
                  {action.icon}
                  <span>{action.label}</span>
                </button>
              </li>
            ))}
          </ul>
        </div>
      </div>

      {/* Mobile bottom sheet */}
      <div className="sm:hidden fixed inset-0 z-50">
        <div 
          className={`absolute inset-0 bg-black bg-opacity-60 backdrop-blur-sm ${isClosing ? 'animate-backdrop-exit' : 'animate-backdrop-enter'}`} 
          onClick={handleClose}
        />
        <div
          ref={menuRef}
          className={`absolute bottom-0 left-0 right-0 bg-slate-50 dark:bg-slate-800 rounded-t-2xl p-4 shadow-2xl ${isClosing ? 'animate-sheet-exit' : 'animate-sheet-enter'}`}
        >
          <div className="absolute top-0 left-1/2 -translate-x-1/2 w-12 h-1.5 bg-slate-300 dark:bg-slate-600 rounded-full mt-2" />
          <ul className="mt-4 space-y-1">
             {actions.map((action, index) => (
              <li key={index}>
                <button
                  onClick={() => handleActionClick(action)}
                  className={`w-full flex items-center gap-4 px-4 py-3.5 text-left rounded-lg text-lg transition-colors active:scale-[0.98] ${
                    action.isDestructive
                      ? 'text-red-600 dark:text-red-400 bg-slate-100 dark:bg-slate-900/50 hover:bg-red-100 dark:hover:bg-red-900/80'
                      : 'text-slate-800 dark:text-slate-100 bg-slate-100 dark:bg-slate-700/50 hover:bg-slate-200 dark:hover:bg-slate-700'
                  }`}
                >
                  <div className={`${action.isDestructive ? '' : 'text-slate-600 dark:text-slate-300'}`}>
                    {action.icon}
                  </div>
                  <span className="font-medium">{action.label}</span>
                </button>
              </li>
            ))}
          </ul>
           <button 
            onClick={handleClose} 
            className="w-full mt-4 px-4 py-3.5 rounded-lg text-lg font-semibold bg-slate-200 dark:bg-slate-700 text-slate-800 dark:text-slate-100 hover:bg-slate-300 dark:hover:bg-slate-600 transition-colors active:scale-[0.98]"
          >
            取消
          </button>
        </div>
      </div>
    </>
  );
};

export default ContextMenu;