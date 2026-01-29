import React from 'react';
import { CheckIcon, ExclamationTriangleIcon } from '../../components/ui/icons';
import Button from '../../components/ui/Button';

interface NotificationProps {
    title?: string;
    message: string;
    type?: 'success' | 'error' | 'info';
    onConfirm?: () => void;
    closeWindow: () => void;
}

export const NotificationModule: React.FC<NotificationProps> = ({ message, type = 'info', onConfirm, closeWindow }) => {
    return (
        <div className="space-y-6">
            <div className="flex items-start gap-4">
                {type === 'success' 
                    ? <div className="w-12 h-12 rounded-full bg-green-100 dark:bg-green-900/50 flex items-center justify-center flex-shrink-0 text-green-600 dark:text-green-400"><CheckIcon className="w-7 h-7" /></div> 
                    : <div className="w-12 h-12 rounded-full bg-red-100 dark:bg-red-900/50 flex items-center justify-center flex-shrink-0 text-red-600 dark:text-red-400"><ExclamationTriangleIcon className="w-7 h-7" /></div>
                }
                <p className="text-slate-700 dark:text-slate-200 text-lg leading-relaxed font-medium pt-1">{message}</p>
            </div>
            <div className="flex justify-end items-center pt-2">
                <Button onClick={() => { if (onConfirm) onConfirm(); closeWindow(); }}>好的</Button>
            </div>
        </div>
    );
};