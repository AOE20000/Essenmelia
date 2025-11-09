import React from 'react';
import { PlusIcon, ChevronUpIcon } from './icons';

interface FABProps {
  onClick: () => void;
  mode: 'add' | 'toTop';
}

const FAB: React.FC<FABProps> = ({ onClick, mode }) => {
  const isAddMode = mode === 'add';
  const Icon = isAddMode ? PlusIcon : ChevronUpIcon;

  return (
    <button
      key={mode}
      onClick={onClick}
      className="fixed bottom-8 right-8 bg-slate-900 dark:bg-slate-200 text-white dark:text-slate-900 rounded-2xl w-16 h-16 flex items-center justify-center shadow-lg hover:bg-slate-700 dark:hover:bg-slate-300 focus:outline-none focus:ring-4 focus:ring-slate-400 dark:focus:ring-offset-slate-900 transition-all duration-300 ease-in-out hover:scale-105 active:scale-90 animate-content-enter"
      style={{ animationDelay: '0ms' }}
      aria-label={isAddMode ? "添加新事件" : "返回顶部"}
    >
      <Icon className="w-8 h-8" />
    </button>
  );
};

export default FAB;