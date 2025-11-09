import React from 'react';
import { ChevronRightIcon } from './icons';

interface ControlsBarProps {
    onClose: () => void;
}

const ControlsBar: React.FC<ControlsBarProps> = ({ onClose }) => {
    return (
        <div className="flex items-center justify-center">
            <button
                onClick={onClose}
                className="bg-white dark:bg-slate-700 hover:bg-slate-100 dark:hover:bg-slate-600 border border-slate-300 dark:border-slate-600 rounded-full w-11 h-11 flex items-center justify-center text-slate-600 dark:text-slate-300 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-500 dark:focus:ring-offset-slate-800 transition-all duration-300 active:scale-90"
                aria-label={'关闭详情视图'}
            >
                <ChevronRightIcon className="w-6 h-6" />
            </button>
        </div>
    );
};

export default ControlsBar;