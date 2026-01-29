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
      className="fixed bottom-8 right-8 bg-brand-600 dark:bg-brand-500 text-white rounded-2xl w-16 h-16 flex items-center justify-center shadow-glow hover:shadow-glow-sm hover:bg-brand-700 dark:hover:bg-brand-400 transition-all duration-300 ease-out hover:scale-110 active:scale-95 animate-content-enter z-50"
      style={{ animationDelay: '0ms' }}
      aria-label={isAddMode ? "添加新事件" : "返回顶部"}
    >
      <Icon className="w-8 h-8" />
    </button>
  );
};

export default FAB;