
import React from 'react';
import { LoadingSpinnerIcon, CheckIcon, ExclamationTriangleIcon } from './icons';

interface SnackbarProps {
  isOpen: boolean;
  message: string;
  icon?: React.ReactNode;
  bottomClass?: string;
  type?: 'info' | 'success' | 'error' | 'loading';
}

const Snackbar: React.FC<SnackbarProps> = ({ isOpen, message, icon, bottomClass = 'bottom-8', type = 'info' }) => {
  const [isRendered, setIsRendered] = React.useState(false);

  React.useEffect(() => {
    if (isOpen) {
      setIsRendered(true);
    }
  }, [isOpen]);

  const handleAnimationEnd = () => {
    if (!isOpen) {
      setIsRendered(false);
    }
  };

  if (!isRendered) {
    return null;
  }
  
  const animationClass = isOpen ? 'animate-content-enter' : 'animate-dialog-exit';

  const typeConfig = {
    loading: {
      icon: <LoadingSpinnerIcon className="w-5 h-5" />,
      style: 'bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-200 border-slate-200 dark:border-slate-700',
    },
    info: {
        icon: null,
        style: 'bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-200 border-slate-200 dark:border-slate-700',
    },
    success: {
        icon: <CheckIcon className="w-5 h-5" />,
        style: 'bg-green-50 dark:bg-green-900/30 text-green-700 dark:text-green-300 border-green-200 dark:border-green-700',
    },
    error: {
        icon: <ExclamationTriangleIcon className="w-5 h-5" />,
        style: 'bg-red-50 dark:bg-red-900/30 text-red-700 dark:text-red-300 border-red-200 dark:border-red-700',
    }
  };
  
  const currentConfig = typeConfig[type] || typeConfig.info;

  // Icon precedence: prop `icon` > config `icon` > null
  const finalIcon = icon !== undefined ? icon : currentConfig.icon;

  return (
    <div 
        className={`fixed ${bottomClass} left-8 z-50 ${animationClass}`}
        onAnimationEnd={handleAnimationEnd}
        role="status"
        aria-live="polite"
    >
      <div className={`flex items-center gap-3 rounded-2xl px-5 py-3 shadow-xl border ${currentConfig.style}`}>
        {finalIcon && <div>{finalIcon}</div>}
        <span className="font-semibold text-sm">{message}</span>
      </div>
    </div>
  );
};

export default Snackbar;