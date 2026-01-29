import React from 'react';
import Button from '../../components/ui/Button';
import { ExclamationTriangleIcon } from '../../components/ui/icons';

interface ConfirmDialogProps {
    title?: string;
    message: string;
    confirmText?: string;
    cancelText?: string;
    isDestructive?: boolean;
    onConfirm: () => void;
    closeWindow: () => void;
}

export const ConfirmDialogModule: React.FC<ConfirmDialogProps> = ({ 
    message, confirmText = '确认', cancelText = '取消', isDestructive = false, onConfirm, closeWindow 
}) => {
    const handleConfirm = () => {
        onConfirm();
        closeWindow();
    };

    return (
        <div className="space-y-6">
            <div className="flex items-start gap-4">
                {isDestructive && (
                    <div className="w-12 h-12 rounded-full bg-red-100 dark:bg-red-900/30 flex items-center justify-center flex-shrink-0 text-red-600 dark:text-red-400">
                        <ExclamationTriangleIcon className="w-7 h-7" />
                    </div>
                )}
                <div>
                    <p className="text-slate-700 dark:text-slate-200 text-lg leading-relaxed font-medium pt-1">{message}</p>
                </div>
            </div>
            <div className="flex justify-end gap-3 pt-2">
                <Button variant="secondary" onClick={closeWindow}>{cancelText}</Button>
                <Button variant={isDestructive ? 'danger' : 'primary'} onClick={handleConfirm}>{confirmText}</Button>
            </div>
        </div>
    );
};